import { IconAgenda } from '../../components/ui/Icon'

export default function Agenda() {
  return (
    <div className="clx-placeholder">
      <div className="clx-placeholder-icon">
        <IconAgenda size={26} />
      </div>
      <h3>Agenda</h3>
      <p>
        Calendário (dia / semana / mês) com os serviços agendados. Visualização
        rápida por profissional e por data.
      </p>
      <span className="clx-placeholder-badge">Em desenvolvimento</span>
    </div>
  )
}
