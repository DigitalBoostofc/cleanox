import PocketBase from 'pocketbase'

const PB_URL = import.meta.env.VITE_PB_URL ?? 'http://127.0.0.1:8090'

export const pb = new PocketBase(PB_URL)

// Desabilita o cancelamento automático de requisições para evitar conflitos
// com o StrictMode do React (que monta/desmonta componentes duas vezes em dev).
pb.autoCancellation(false)
