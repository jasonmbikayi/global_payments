import React from "react";
import ReactDOM from "react-dom/client";
import "./index.css";
import "./index.jsx"; // Ensure this line is present to include your main React code

// Note: The original index.jsx contained a lot of code for forms and API calls.
// For simplicity, we will just create a basic React component structure here.
// You should move your existing components (RegisterForm, AddCardForm, etc.) into separate files and import them as needed.

// This is a placeholder.  

// You should move your app code into a React component, e.g. App.jsx
// For now, render a placeholder:
function App() {
  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="container max-w-6xl bg-white rounded-xl shadow-2xl overflow-hidden">
        <header className="gradient-bg text-white p-6">
          <div className="flex justify-between items-center">
            <div className="flex items-center">
              <i className="fas fa-money-bill-transfer text-3xl mr-3"></i>
              <h1 className="text-2xl font-bold">P2P Payments</h1>
            </div>
            <div className="flex items-center space-x-4">
              <button className="bg-white text-blue-600 px-4 py-2 rounded-lg font-semibold">Register</button>
              <button className="bg-white text-blue-600 px-4 py-2 rounded-lg font-semibold">Login</button>
            </div>
          </div>
        </header>
        <main className="p-6">
          <p className="text-center text-gray-500">React app placeholder. Move your HTML UI into React components.</p>
        </main>
        <footer className="bg-gray-800 text-white p-6 text-center">
          <p>© 2025 P2P Payments. All rights reserved.</p>
        </footer>
      </div>
    </div>
  );
}

const root = ReactDOM.createRoot(document.getElementById("root"));
root.render(<App />);