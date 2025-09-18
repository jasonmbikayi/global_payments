// frontend/src/index.jsx
import React, { useState, useEffect } from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';

// ---------- Safe fetch wrapper ----------
async function api(url, opts = {}) {
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    ...opts,
  });

  const text = await res.text();
  let data;
  if (!text) data = {}; // empty response
  else {
    try {
      data = JSON.parse(text);
    } catch (err) {
      console.error('Invalid JSON response from', url, ':', text);
      throw new Error('Invalid JSON response from server');
    }
  }

  if (!res.ok) {
    const errMsg = data?.error || `HTTP ${res.status}`;
    throw new Error(errMsg);
  }

  return data;
}

// ---------- RegisterForm ----------
function RegisterForm({ onRegistered }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [error, setError] = useState(null);

  async function submit(e) {
    e.preventDefault();
    setError(null);
    try {
      const res = await api('/api/register', {
        method: 'POST',
        body: JSON.stringify({ email, password, name })
      });
      if (res.ok) onRegistered(res.user);
      else setError(res.error || 'Registration failed');
    } catch (err) {
      setError(err.message);
    }
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

// ---------- AddCardForm ----------
function AddCardForm({ onAdded }) {
  const [number, setNumber] = useState('');
  const [exp, setExp] = useState('');
  const [cvc, setCvc] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  async function submit(e) {
    e.preventDefault();
    setLoading(true); setError(null);
    try {
      const res = await api('/api/payment_methods', {
        method: 'POST',
        body: JSON.stringify({ number, exp, cvc })
      });
      if (res.ok) onAdded(res.paymentMethod);
      else setError(res.error || 'Failed to add card');
    } catch (err) {
      setError(err.message);
    }
    setLoading(false);
  }

  return (
    <form onSubmit={submit} className="p-4 border rounded">
      <h3 className="text-lg font-bold mb-2">Add Card</h3>
      <input className="block w-full p-2 mb-2" value={number} onChange={e => setNumber(e.target.value)} placeholder="Card number (test)" />
      <input className="block w-full p-2 mb-2" value={exp} onChange={e => setExp(e.target.value)} placeholder="MM/YY" />
      <input className="block w-full p-2 mb-2" value={cvc} onChange={e => setCvc(e.target.value)} placeholder="CVC" />
      {error && <div className="text-red-600">{error}</div>}
      <button className="px-4 py-2 bg-green-600 text-white rounded" type="submit" disabled={loading}>{loading ? 'Adding...' : 'Add Card'}</button>
    </form>
  );
}

// ---------- TransferForm ----------
function TransferForm({ paymentMethods, onSent }) {
  const [recipientEmail, setRecipientEmail] = useState('');
  const [amount, setAmount] = useState('');
  const [currency, setCurrency] = useState('usd');
  const [paymentMethodId, setPaymentMethodId] = useState('');
  const [message, setMessage] = useState(null);

  async function submit(e) {
    e.preventDefault();
    setMessage(null);
    const payload = { recipientEmail, amount: Number(amount), currency, paymentMethodId };

    try {
      const res = await api('/api/transfer', {
        method: 'POST',
        body: JSON.stringify(payload)
      });
      if (res.ok) {
        setMessage({ type: 'success', text: 'Transfer sent', tx: res.transaction });
        if (onSent) onSent(res.transaction);
      } else {
        setMessage({ type: 'error', text: res.error || 'Transfer failed' });
      }
    } catch (err) {
      setMessage({ type: 'error', text: err.message });
    }
  }

  return (
    <form onSubmit={submit} className="p-4 border rounded">
      <h3 className="text-lg font-bold mb-2">Send Money (P2P)</h3>
      <input className="block w-full p-2 mb-2" value={recipientEmail} onChange={e => setRecipientEmail(e.target.value)} placeholder="Recipient email" />
      <div className="flex gap-2 mb-2">
        <input className="flex-1 p-2" value={amount} onChange={e => setAmount(e.target.value)} placeholder="Amount" />
        <select className="p-2" value={currency} onChange={e => setCurrency(e.target.value)}>
          <option value="usd">USD</option>
          <option value="eur">EUR</option>
          <option value="brl">BRL</option>
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

// ---------- AdminDashboard ----------
function AdminDashboard() {
  const [txs, setTxs] = useState([]);

  useEffect(() => {
    async function load() {
      try {
        const res = await api('/api/admin/transactions');
        if (res.ok) setTxs(res.transactions || []);
      } catch (err) {
        console.error('Failed to load admin transactions:', err.message);
      }
    }
    load();
  }, []);

  return (
    <div className="p-4 border rounded">
      <h3 className="text-lg font-bold mb-2">Admin Dashboard</h3>
      <table className="w-full table-auto border-collapse">
        <thead>
          <tr><th>id</th><th>sender</th><th>recipient</th><th>amount</th><th>currency</th><th>status</th><th>provider</th></tr>
        </thead>
        <tbody>
          {txs.map(tx => (
            <tr key={tx.id} className="border-t">
              <td>{tx.id}</td>
              <td>{tx.sender}</td>
              <td>{tx.recipient}</td>
              <td>{tx.amount}</td>
              <td>{tx.currency}</td>
              <td>{tx.status}</td>
              <td>{tx.provider}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// ---------- AppRoot ----------
function AppRoot() {
  const [user, setUser] = useState(null);
  const [paymentMethods, setPaymentMethods] = useState([]);
  const [refresh, setRefresh] = useState(false);
  const [loadingUser, setLoadingUser] = useState(false);
  const [userError, setUserError] = useState(null);
  const [loadingPMs, setLoadingPMs] = useState(false);
  const [pmError, setPmError] = useState(null);

  useEffect(() => {
    async function loadUser() {
      setLoadingUser(true);
      setUserError(null);
      try {
        const res = await api('/api/me');
        if (res.ok && res.user) {
          setUser(res.user);
          // Fetch payment methods
          setLoadingPMs(true);
          setPmError(null);
          try {
            const pmRes = await api('/api/payment_methods_list');
            if (pmRes.ok) setPaymentMethods(pmRes.paymentMethods || []);
            else setPmError(pmRes.error || 'Failed to load payment methods');
          } catch (err) {
            setPmError(err.message);
          }
          setLoadingPMs(false);
        } else {
          setUserError(res.error || 'Failed to load user');
        }
      } catch (err) {
        setUserError(err.message);
      }
      setLoadingUser(false);
    }
    if (user) loadUser();
  }, [user, refresh]);

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold mb-4">Global Payments</h1>
      <div className="grid grid-cols-2 gap-4">
        <div>
          {!user && !loadingUser && <RegisterForm onRegistered={u => setUser(u)} />}
          {loadingUser && <div className="p-4 border rounded text-gray-600">Loading user...</div>}
          {userError && <div className="p-4 border rounded text-red-600">{userError}</div>}
          {user && <div className="p-4 border rounded mb-4">Welcome, <b>{user.name}</b></div>}
          {user && loadingPMs && <div className="p-4 border rounded text-gray-600">Loading payment methods...</div>}
          {user && pmError && <div className="p-4 border rounded text-red-600">{pmError}</div>}
          {user && <AddCardForm onAdded={() => setRefresh(!refresh)} />}
        </div>
        <div>
          {user ? <TransferForm paymentMethods={paymentMethods} onSent={tx => console.log(tx)} /> : <div className="p-4 border rounded">Please register to send money</div>}
          <div className="mt-4">
            <AdminDashboard />
          </div>
        </div>
      </div>
    </div>
  );
}

// ---------- Render App ----------
const root = document.getElementById('root') || document.createElement('div');
root.id = 'root';
if (!document.body.contains(root)) document.body.appendChild(root);
ReactDOM.createRoot(root).render(<AppRoot />);

export default AppRoot;