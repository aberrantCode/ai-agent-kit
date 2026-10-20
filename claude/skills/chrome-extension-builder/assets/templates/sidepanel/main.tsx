// entrypoints/sidepanel/main.tsx
//
// Starter mount script for the side panel HTML entrypoint (index.html in
// this folder). Replace the markup below with real UI; wire it to the
// background worker via `browser.runtime.sendMessage` /
// `browser.runtime.onMessage` — see ../../references/messaging.md.
import { createRoot } from 'react-dom/client';

function App() {
  return (
    <div style={{ padding: '1rem', fontFamily: 'system-ui, sans-serif' }}>
      <h1>Side Panel</h1>
      <p>Starter side panel. Replace this component with your UI.</p>
    </div>
  );
}

const container = document.getElementById('root');
if (container) {
  createRoot(container).render(<App />);
}
