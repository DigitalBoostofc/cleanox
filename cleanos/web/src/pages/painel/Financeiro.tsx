import { IconFinanceiro } from '../../components/ui/Icon'

export default function Financeiro() {
  return (
    <div className="clx-placeholder">
      <div className="clx-placeholder-icon">
        <IconFinanceiro size={26} />
      </div>
      <h3>Financeiro</h3>
      <p>
        Recebido no mês, pendente, ticket médio. Lançamentos com cliente, data,
        valor, forma de pagamento e coluna "a repassar ao profissional" — admin
        marca como pago manualmente.
      </p>
      <span className="clx-placeholder-badge">Em desenvolvimento</span>
    </div>
  )
}
