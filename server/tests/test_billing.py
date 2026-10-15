import asyncio
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from types import SimpleNamespace
import pytest
from cryptography.fernet import Fernet
from fastapi.testclient import TestClient
from app import AppleVerifier, Question, create_app, production_app, MAX_SOURCE_BYTES
from ledger import Ledger, Rejected

@pytest.fixture
def ledger(tmp_path):
    return Ledger(tmp_path/'credits.db', Fernet.generate_key())

class Verifier:
    def identity(self, proof):
        if proof not in ('owner', 'other'):
            raise Rejected('invalid_apple_identity', 401)
        return proof
    def transaction(self, proof, wallet=None):
        if proof not in ('purchase', 'refund') or wallet not in (None, 'owner'):
            raise Rejected('invalid_transaction', 403)
        return SimpleNamespace(transactionId='tx1', quantity=1, signedDate=1, revocationDate=1 if proof=='refund' else None), 'owner'
    def notification(self, proof):
        if proof not in ('refund', 'reverse'):
            raise Rejected('invalid_notification', 403)
        return SimpleNamespace(signedDate=1 if proof=='refund' else 2, notificationType='REFUND' if proof=='refund' else 'REFUND_REVERSED',
                               data=SimpleNamespace(signedTransactionInfo='purchase'))

class Provider:
    calls = 0
    fail = False
    async def answer(self, question):
        self.calls += 1
        if self.fail:
            raise RuntimeError('private provider details must not escape')
        return 'A contextual explanation.'

@pytest.fixture
def client(ledger):
    provider = Provider()
    with TestClient(create_app(ledger, Verifier(), provider)) as client:
        client.headers['Authorization'] = 'Bearer owner'
        client.provider = provider
        yield client

def body(**changes):
    return dict(requestId=str(uuid.uuid4()), task='explain', source='book passage', **changes)

def buy(client):
    return client.post('/v1/purchases', json={'signedTransaction':'purchase'})

def test_purchase_replay_credits_once(client):
    assert buy(client).json()['balance'] == 500
    assert buy(client).json()['balance'] == 500
    assert client.get('/v1/wallet').json()['balance'] == 500

def test_no_purchase_no_provider_call(client):
    assert client.post('/v1/questions', json=body()).status_code == 402
    assert client.provider.calls == 0

def test_request_replay_returns_same_answer_and_single_debit(client):
    buy(client); question = body()
    first = client.post('/v1/questions', json=question)
    second = client.post('/v1/questions', json=question)
    assert first.json() == second.json()
    assert second.json()['balance'] == 499
    assert client.provider.calls == 1
    question['source'] = 'different source'
    assert client.post('/v1/questions', json=question).status_code == 409

def test_failure_refunds_once_and_does_not_retry_upstream(client):
    buy(client); client.provider.fail = True; question = body()
    for _ in range(2):
        response = client.post('/v1/questions', json=question)
        assert response.status_code == 502
        assert 'private provider' not in response.text
    assert client.get('/v1/wallet').json()['balance'] == 500
    assert client.provider.calls == 1

def test_untrusted_fields_and_oversize_sources(client):
    buy(client)
    for field in ('model', 'url', 'max_tokens', 'key', 'balance', 'credits', 'messages'):
        assert client.post('/v1/questions', json=body(**{field:'untrusted'})).status_code == 400
    assert client.post('/v1/questions', json={**body(), 'task':'document'}).status_code == 400
    assert client.post('/v1/questions', json={**body(), 'source':'书'*2001}).status_code == 400
    assert client.post('/v1/questions', content=b'x'*48001).status_code == 413
    assert client.provider.calls == 0

def test_identity_and_purchase_cannot_be_spoofed(client):
    assert client.get('/v1/wallet', headers={'Authorization':'Bearer forged'}).status_code == 401
    assert client.post('/v1/purchases', json={'signedTransaction':'forged'}).status_code == 403
    assert client.post('/v1/purchases', json={'signedTransaction':'purchase'}, headers={'Authorization':'Bearer other'}).status_code == 403

def test_recovery_is_scoped_and_not_billed(client):
    buy(client); question = body(); client.post('/v1/questions', json=question)
    path = '/v1/questions/' + question['requestId']
    assert client.get(path).json()['balance'] == 499
    assert client.get(path, headers={'Authorization':'Bearer other'}).status_code == 404
    assert client.delete('/v1/answers').json()['deleted']
    assert client.get(path).status_code == 410
    assert client.post('/v1/questions', json=question).status_code == 410
    assert client.provider.calls == 1

def test_latest_recovery_survives_rejected_attempt_and_is_private(client, ledger):
    buy(client)
    original = body()
    ledger.reserve('owner', original['requestId'], 'original')
    assert client.post('/v1/questions', json=body()).status_code == 409
    assert client.get('/v1/questions/latest').status_code == 409
    ledger.finish('owner', original['requestId'], 'Recovered answer')
    result = client.get('/v1/questions/latest').json()
    assert result['answer'] == 'Recovered answer'
    assert result['balance'] == 499
    assert client.get('/v1/questions/latest', headers={'Authorization':'Bearer other'}).status_code == 404
    assert client.provider.calls == 0

def test_expired_answer_is_unavailable_even_before_cleanup(ledger):
    ledger.credit('owner', 'tx')
    ledger.reserve('owner', 'id', 'same', now=time.time()-86401)
    ledger.finish('owner', 'id', 'Old answer')
    with pytest.raises(Rejected, match='answer_expired'):
        ledger.latest('owner')

def test_refund_before_redemption_blocks_old_purchase(client):
    assert client.post('/v1/apple-notifications', json={'signedPayload':'refund'}).status_code == 200
    assert buy(client).status_code == 403
    assert client.get('/v1/wallet').json()['balance'] == 0

def test_refund_after_use_no_double_refund_and_reversal(client):
    buy(client); client.post('/v1/questions', json=body())
    for _ in range(2):
        assert client.post('/v1/apple-notifications', json={'signedPayload':'refund'}).status_code == 200
    assert client.get('/v1/wallet').json()['balance'] == 0
    assert client.post('/v1/questions', json=body()).status_code == 402
    for _ in range(2):
        assert client.post('/v1/apple-notifications', json={'signedPayload':'reverse'}).status_code == 200
    assert client.get('/v1/wallet').json()['balance'] == 499

def test_signature_required_for_apple_notifications(client):
    assert client.post('/v1/apple-notifications', json={'signedPayload':'forged'}).status_code == 403

def test_concurrent_purchase_and_last_credit(ledger):
    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(lambda _: ledger.credit('owner','same'), range(20)))
    assert ledger.wallet('owner')['balance'] == 500
    with ledger.transaction() as db:
        db.execute('UPDATE wallets SET balance=1')
    def reserve(n):
        try:
            ledger.reserve('owner',str(n),'hash'); return True
        except Rejected:
            return False
    with ThreadPoolExecutor(max_workers=8) as pool:
        result = list(pool.map(reserve, range(20)))
    assert sum(result) == 1
    assert ledger.wallet('owner')['balance'] == 0

def test_crash_cleanup_returns_credit_once_and_erases_expired_answer(ledger):
    ledger.credit('owner','tx')
    ledger.reserve('owner','lost','hash',now=time.time()-400)
    ledger.maintenance(); ledger.maintenance()
    assert ledger.wallet('owner')['balance'] == 500
    ledger.reserve('owner','answer','hash',now=time.time()-90000)
    ledger.finish('owner','answer','sensitive answer')
    with ledger.connect() as db:
        assert b'sensitive answer' not in db.execute("SELECT answer FROM requests WHERE id='answer'").fetchone()[0]
    ledger.maintenance()
    with pytest.raises(Rejected, match='answer_expired'):
        ledger.result('owner','answer')

def test_daily_spending_and_rate_limits_include_failures(ledger):
    ledger.daily_limit=1
    ledger.credit('owner','tx'); ledger.reserve('owner','one','hash'); ledger.finish('owner','one')
    with pytest.raises(Rejected, match='daily_budget_reached'):
        ledger.reserve('owner','two','hash')
    ledger.rate('limit',1)
    with pytest.raises(Rejected, match='rate_limited'):
        ledger.rate('limit',1)

def test_production_has_no_mock_or_keyless_fallback(monkeypatch):
    monkeypatch.delenv('DEEPSEEK_API_KEY', raising=False)
    with pytest.raises(RuntimeError, match='DEEPSEEK_API_KEY'):
        production_app()

def test_real_apple_verifier_rejects_unsigned_identity():
    from appstoreserverlibrary.models.Environment import Environment
    from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier
    verifier = AppleVerifier.__new__(AppleVerifier)
    verifier.environment = 'Production'
    verifier.verifier = SignedDataVerifier([], False, Environment.PRODUCTION, 'org.deepreader.macos', 6821368213)
    with pytest.raises(Rejected, match='invalid_apple_identity'):
        verifier.identity('eyJhbGciOiJub25lIn0.eyJhcHBUcmFuc2FjdGlvbklkIjoiMTIzIn0.')


def test_out_of_order_refund_and_reversal_before_credit(ledger):
    ledger.reverse_refund('owner','tx',20)
    ledger.refund('owner','tx',10)
    assert ledger.credit('owner','tx')['balance'] == 500
    ledger.refund('owner','tx',30)
    ledger.reverse_refund('owner','tx',20)
    assert ledger.wallet('owner')['balance'] == 0
