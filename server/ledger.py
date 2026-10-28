# SPDX-License-Identifier: AGPL-3.0-or-later
"""Single-host, durable credit ledger. All balance changes use BEGIN IMMEDIATE."""
import hashlib
import sqlite3
import time
import uuid
from contextlib import contextmanager
from cryptography.fernet import Fernet

PRODUCT = 'org.deepreader.questions.500'
PACK_SIZE = 500
ANSWER_TTL = 86400

class Rejected(Exception):
    def __init__(self, code, status=400):
        self.code, self.status = code, status
        super().__init__(code)

class Ledger:
    def __init__(self, path, encryption_key, daily_limit=1000, wallet_daily_limit=100):
        self.path = str(path)
        self.cipher = Fernet(encryption_key)
        self.daily_limit = daily_limit
        self.wallet_daily_limit = wallet_daily_limit
        with self.connect() as db:
            db.executescript('''
              PRAGMA journal_mode=WAL;
              CREATE TABLE IF NOT EXISTS wallets (id TEXT PRIMARY KEY, balance INTEGER NOT NULL DEFAULT 0);
              CREATE TABLE IF NOT EXISTS purchases (
                id TEXT PRIMARY KEY, wallet TEXT NOT NULL, credits INTEGER NOT NULL,
                revoked INTEGER NOT NULL DEFAULT 0, credited INTEGER NOT NULL DEFAULT 0, event_time INTEGER NOT NULL DEFAULT 0);
              CREATE TABLE IF NOT EXISTS requests (
                wallet TEXT NOT NULL, id TEXT NOT NULL, fingerprint TEXT NOT NULL,
                state TEXT NOT NULL, created REAL NOT NULL, answer BLOB,
                PRIMARY KEY(wallet,id));
              CREATE INDEX IF NOT EXISTS request_time ON requests(created);
              CREATE TABLE IF NOT EXISTS limits (key TEXT PRIMARY KEY, count INTEGER NOT NULL);
            ''')

    def connect(self):
        db = sqlite3.connect(self.path, timeout=10)
        db.row_factory = sqlite3.Row
        return db

    @contextmanager
    def transaction(self):
        db = self.connect()
        try:
            db.execute('BEGIN IMMEDIATE')
            yield db
            db.commit()
        except BaseException:
            db.rollback()
            raise
        finally:
            db.close()

    @staticmethod
    def account_token(wallet):
        return str(uuid.uuid5(uuid.NAMESPACE_URL, 'deepreader-wallet:' + wallet))

    def wallet(self, wallet):
        with self.transaction() as db:
            db.execute('INSERT OR IGNORE INTO wallets(id) VALUES (?)', (wallet,))
            balance = db.execute('SELECT balance FROM wallets WHERE id=?', (wallet,)).fetchone()[0]
        return {'balance': max(0, balance), 'accountToken': self.account_token(wallet)}

    def rate(self, key, maximum):
        with self.transaction() as db:
            db.execute('INSERT INTO limits VALUES (?,1) ON CONFLICT(key) DO UPDATE SET count=count+1', (key,))
            count = db.execute('SELECT count FROM limits WHERE key=?', (key,)).fetchone()[0]
        if count > maximum:
            raise Rejected('rate_limited', 429)

    def credit(self, wallet, transaction, quantity=1):
        if quantity != 1:
            raise Rejected('invalid_quantity')
        with self.transaction() as db:
            db.execute('INSERT OR IGNORE INTO wallets(id) VALUES (?)', (wallet,))
            existing = db.execute('SELECT * FROM purchases WHERE id=?', (transaction,)).fetchone()
            if existing and existing['wallet'] != wallet:
                raise Rejected('purchase_owner_mismatch', 403)
            if existing and existing['revoked']:
                raise Rejected('purchase_revoked', 403)
            if existing and not existing['credited']:
                db.execute('UPDATE purchases SET credited=1 WHERE id=?', (transaction,))
                db.execute('UPDATE wallets SET balance=balance+? WHERE id=?', (PACK_SIZE, wallet))
            if not existing:
                db.execute('INSERT INTO purchases(id,wallet,credits,credited) VALUES (?,?,?,1)', (transaction, wallet, PACK_SIZE))
                db.execute('UPDATE wallets SET balance=balance+? WHERE id=?', (PACK_SIZE, wallet))
        return self.wallet(wallet)

    def refund(self, wallet, transaction, event_time=1):
        # Tombstones prevent a refunded transaction delivered before redemption being replayed.
        with self.transaction() as db:
            existing = db.execute('SELECT * FROM purchases WHERE id=?', (transaction,)).fetchone()
            if existing and existing['wallet'] != wallet:
                raise Rejected('purchase_owner_mismatch', 403)
            if existing and event_time <= existing['event_time']:
                return
            if existing and not existing['revoked']:
                if existing['credited']:
                    db.execute('UPDATE wallets SET balance=balance-? WHERE id=?', (existing['credits'], wallet))
                db.execute('UPDATE purchases SET revoked=1,event_time=? WHERE id=?', (event_time, transaction))
            elif not existing:
                db.execute('INSERT INTO purchases(id,wallet,credits,revoked,event_time) VALUES (?,?,?,1,?)', (transaction, wallet, PACK_SIZE, event_time))
            else:
                db.execute('UPDATE purchases SET event_time=? WHERE id=?', (event_time, transaction))

    def reverse_refund(self, wallet, transaction, event_time=2):
        with self.transaction() as db:
            row = db.execute('SELECT * FROM purchases WHERE id=?', (transaction,)).fetchone()
            if row and row['wallet'] != wallet:
                raise Rejected('purchase_owner_mismatch', 403)
            if row and event_time <= row['event_time']:
                return
            if row:
                if row['revoked'] and row['credited']:
                    db.execute('UPDATE wallets SET balance=balance+? WHERE id=?', (row['credits'], wallet))
                db.execute('UPDATE purchases SET revoked=0,event_time=? WHERE id=?', (event_time, transaction))
            else:
                db.execute('INSERT INTO purchases(id,wallet,credits,event_time) VALUES (?,?,?,?)', (transaction, wallet, PACK_SIZE, event_time))

    def reserve(self, wallet, request_id, fingerprint, now=None):
        now = time.time() if now is None else now
        with self.transaction() as db:
            old = db.execute('SELECT * FROM requests WHERE wallet=? AND id=?', (wallet, request_id)).fetchone()
            if old:
                if old['fingerprint'] != fingerprint:
                    raise Rejected('request_conflict', 409)
                return self._result(old)
            # Count attempts, including failures, to cap upstream spend from repeated failed calls.
            day = int(now // 86400) * 86400
            if db.execute('SELECT COUNT(*) FROM requests WHERE created>=?', (day,)).fetchone()[0] >= self.daily_limit:
                raise Rejected('daily_budget_reached', 503)
            if db.execute('SELECT COUNT(*) FROM requests WHERE wallet=? AND created>=?', (wallet, day)).fetchone()[0] >= self.wallet_daily_limit:
                raise Rejected('daily_limit', 429)
            if db.execute("SELECT 1 FROM requests WHERE wallet=? AND state='pending'", (wallet,)).fetchone():
                raise Rejected('request_in_progress', 409)
            if not db.execute('UPDATE wallets SET balance=balance-1 WHERE id=? AND balance>0', (wallet,)).rowcount:
                raise Rejected('insufficient_credits', 402)
            db.execute("INSERT INTO requests(wallet,id,fingerprint,state,created) VALUES (?,?,?,'pending',?)", (wallet, request_id, fingerprint, now))
        return None

    def finish(self, wallet, request_id, answer=None):
        with self.transaction() as db:
            result = db.execute("UPDATE requests SET state=?,answer=? WHERE wallet=? AND id=? AND state='pending'",
                                ('done' if answer else 'failed', self.cipher.encrypt(answer.encode()) if answer else None, wallet, request_id))
            if not result.rowcount:
                raise Rejected('request_not_pending', 409)
            if not answer:
                db.execute('UPDATE wallets SET balance=balance+1 WHERE id=?', (wallet,))

    def _result(self, row):
        if row['state'] == 'pending':
            raise Rejected('request_in_progress', 409)
        if row['state'] == 'failed':
            raise Rejected('generation_failed_refunded', 502)
        if not row['answer'] or row['created'] + ANSWER_TTL <= time.time():
            raise Rejected('answer_expired', 410)
        return {'answer': self.cipher.decrypt(row['answer']).decode(), 'requestId': row['id']}

    def result(self, wallet, request_id):
        with self.connect() as db:
            row = db.execute('SELECT * FROM requests WHERE wallet=? AND id=?', (wallet, request_id)).fetchone()
        if not row:
            raise Rejected('request_not_found', 404)
        return self._result(row)

    def latest(self, wallet):
        with self.connect() as db:
            row = db.execute('SELECT * FROM requests WHERE wallet=? ORDER BY created DESC, rowid DESC LIMIT 1', (wallet,)).fetchone()
        if not row:
            raise Rejected('request_not_found', 404)
        return self._result(row)

    def maintenance(self):
        # Run at startup and periodically. Upstream has a strict 90-second total timeout.
        now = time.time()
        with self.transaction() as db:
            for row in db.execute("SELECT wallet,id FROM requests WHERE state='pending' AND created<?", (now-300,)).fetchall():
                db.execute("UPDATE requests SET state='failed' WHERE wallet=? AND id=?", (row['wallet'], row['id']))
                db.execute('UPDATE wallets SET balance=balance+1 WHERE id=?', (row['wallet'],))
            db.execute('UPDATE requests SET answer=NULL WHERE created<? AND answer IS NOT NULL', (now-ANSWER_TTL,))
            # Rate-limit keys are timestamp-prefixed, with no raw IP addresses stored.
            db.execute('DELETE FROM limits WHERE CAST(substr(key,1,instr(key,\':\')-1) AS INTEGER)<?', (int(now//60)-60,))
