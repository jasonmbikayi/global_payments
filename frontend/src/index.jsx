// frontend/src/index.jsx
import React, { useState, useEffect } from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
// Simple fetch wrapper

function api(url, opts = {}) {
  return fetch(url, {
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    ...opts,
  }).then(r => r.json());
}

// ----- RegisterForm -----
function RegisterForm({ onRegistered }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [error, setError] = useState(null);

  async function submit(e) {
    e.preventDefault();
    setError(null);
    try {
      const res = await api('/api/register', { method: 'POST', body: JSON.stringify({ email, password, name }) });
      if (res.ok) onRegistered(res.user);
      else setError(res.error || 'Registration failed');
    } catch (err) { setError(err.message); }
  }

  return (
    <form onSubmit={submit} className="p-4 border rounded">
      <h3 className="text-lg font-bold mb-2">Register</h3>
      <input className="block w-full p-2 mb-2" placeholder="Full name" value={name} onChange={e => setName(e.target.value)} />
      <input className="block w-full p-2 mb-2" placeholder="Email" value={email} onChange={e => setEmail(e.target.value)} />
      <input className="block w-full p-2 mb-2" placeholder="Password" type="password" value={password} onChange={e => setPassword(e.target.value)} />
      {error && <div className="text-red-600">{error}</div>}
      <button className="px-4 py-2 bg-blue-600 text-white rounded" type="submit">Register</button>
    </form>
  );
}

// ----- AddCardForm -----
function AddCardForm({ user, onAdded }) {
  const [cardholder, setCardholder] = useState(user?.name || '');
  const [number, setNumber] = useState('');
  const [exp, setExp] = useState('');
  const [cvc, setCvc] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  async function submit(e) {
    e.preventDefault();
    setLoading(true); setError(null);
    try {
      const res = await api('/api/payment_methods', { method: 'POST', body: JSON.stringify({ cardholder, number, exp, cvc }) });
      if (res.ok) {
        onAdded(res.paymentMethod);
      } else {
        setError(res.error || 'Failed to add card');
      }
    } catch (err) { setError(err.message); }
    setLoading(false);
  }

  return (
    <form onSubmit={submit} className="p-4 border rounded">
      <h3 className="text-lg font-bold mb-2">Add Card</h3>
      <input className="block w-full p-2 mb-2" value={cardholder} onChange={e => setCardholder(e.target.value)} placeholder="Cardholder name" />
      <input className="block w-full p-2 mb-2" value={number} onChange={e => setNumber(e.target.value)} placeholder="Card number (test)" />
      <input className="block w-full p-2 mb-2" value={exp} onChange={e => setExp(e.target.value)} placeholder="MM/YY" />
      <input className="block w-full p-2 mb-2" value={cvc} onChange={e => setCvc(e.target.value)} placeholder="CVC" />
      {error && <div className="text-red-600">{error}</div>}
      <button className="px-4 py-2 bg-green-600 text-white rounded" type="submit" disabled={loading}>{loading ? 'Adding...' : 'Add Card'}</button>
    </form>
  );
}

// ----- TransferForm -----
function TransferForm({ user, onSent }) {
  const [recipientEmail, setRecipientEmail] = useState('');
  const [amount, setAmount] = useState('');
  const [currency, setCurrency] = useState('BRL');
  const [paymentMethodId, setPaymentMethodId] = useState('');
  const [paymentMethods, setPaymentMethods] = useState([]);
  const [message, setMessage] = useState(null);

  useEffect(() => {
    async function loadPM() {
      const res = await api('/api/me');
      if (res.ok) setPaymentMethods(res.user.paymentMethods || []);
    }
    loadPM();
  }, [user]);

  async function submit(e) {
    e.preventDefault();
    setMessage(null);
    const payload = { recipientEmail, amount: Number(amount), currency, paymentMethodId };
    const res = await api('/api/transfer', { method: 'POST', body: JSON.stringify(payload) });
    if (res.ok) {
      setMessage({ type: 'success', text: 'Transfer sent', tx: res.transaction });
      if (onSent) onSent(res.transaction);
    } else {
      setMessage({ type: 'error', text: res.error || 'Transfer failed' });
    }
  }

  return (
    <form onSubmit={submit} className="p-4 border rounded">
      <h3 className="text-lg font-bold mb-2">Send Money (P2P)</h3>
      <input className="block w-full p-2 mb-2" value={recipientEmail} onChange={e => setRecipientEmail(e.target.value)} placeholder="Recipient email" />
      <div className="flex gap-2 mb-2">
        <input className="flex-1 p-2" value={amount} onChange={e => setAmount(e.target.value)} placeholder="Amount" />
        <select className="p-2" value={currency} onChange={e => setCurrency(e.target.value)}>
          <option>BRL</option>
          <option>USD</option>
          <option>EUR</option>
        </select>
      </div>
      <select className="block w-full p-2 mb-2" value={paymentMethodId} onChange={e => setPaymentMethodId(e.target.value)}>
        <option value="">-- choose payment method --</option>
        {paymentMethods.map(pm => (
          <option key={pm.id} value={pm.id}>{pm.brand} ****{pm.last4} exp {pm.exp_month}/{pm.exp_year}</option>
        ))}
      </select>
      <button className="px-4 py-2 bg-indigo-600 text-white rounded" type="submit">Send</button>
      {message && <div className={`mt-2 ${message.type === 'error' ? 'text-red-600' : 'text-green-600'}`}>{message.text}</div>}
    </form>
  );
}

// ----- AdminDashboard -----
function AdminDashboard() {
  const [txs, setTxs] = useState([]);

  useEffect(() => {
    async function load() {
      const res = await api('/api/admin/transactions');
      if (res.ok) setTxs(res.transactions || []);
    }
    load();
  }, []);

  return (
    <div className="p-4 border rounded">
      <h3 className="text-lg font-bold mb-2">Admin Dashboard</h3>
      <table className="w-full table-auto border-collapse">
        <thead><tr><th>id</th><th>from</th><th>to</th><th>amount</th><th>status</th></tr></thead>
        <tbody>
          {txs.map(tx => (
            <tr key={tx.id} className="border-t">
              <td>{tx.id}</td>
              <td>{tx.from_email}</td>
              <td>{tx.to_email}</td>
              <td>{tx.amount} {tx.currency}</td>
              <td>{tx.status}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// ----- AppRoot -----
function AppRoot() {
  const [user, setUser] = useState(null);
  const [refresh, setRefresh] = useState(false); // trigger reload of payment methods

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold mb-4">P2P Payments (Visa/Mastercard) — Demo</h1>
      <div className="grid grid-cols-2 gap-4">
        <div>
          {!user && <RegisterForm onRegistered={u => setUser(u)} />}
          {user && <div className="p-4 border rounded mb-4">Welcome, <b>{user.name}</b></div>}
          {user && <AddCardForm user={user} onAdded={pm => setRefresh(!refresh)} />}
        </div>
        <div>
          {user ? <TransferForm key={refresh} user={user} onSent={tx => console.log(tx)} /> : <div className="p-4 border rounded">Please register to send money</div>}
          <div className="mt-4">
            <AdminDashboard />
          </div>
        </div>
      </div>
    </div>
  );
}

// Render app
const root = document.getElementById('root') || document.createElement('div');
root.id = 'root';
if(!document.body.contains(root)) document.body.appendChild(root);
ReactDOM.createRoot(root).render(<AppRoot />);

export default AppRoot;

