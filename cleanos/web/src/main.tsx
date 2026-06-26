import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './styles/tokens.css'
import './styles/global.css'
import App from './App'

// Recarrega a página uma vez quando um novo SW assume o controle (auto-update sem loop).
if ('serviceWorker' in navigator) {
  let reloading = false
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (!reloading) {
      reloading = true
      window.location.reload()
    }
  })
}

const rootEl = document.getElementById('root')
if (!rootEl) throw new Error('Elemento #root não encontrado no DOM.')

createRoot(rootEl).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
