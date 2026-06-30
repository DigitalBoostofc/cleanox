/**
 * KIT de componentes compartilhados do módulo Financeiro (barrel).
 *
 * As telas do Financeiro (Visão geral, Lançamentos, Contas a pagar/receber,
 * Categorias, Relatórios, Limites, Carteiras) importam DAQUI. As assinaturas
 * destes componentes são ESTÁVEIS — não mude sem alinhar com os consumidores.
 */

export { FinKpiCard } from './FinKpiCard'
export type { FinKpiCardProps, FinKpiTone } from './FinKpiCard'

export { CategoriaIcon } from './CategoriaIcon'
export type { CategoriaIconProps } from './CategoriaIcon'

export { StatusChip } from './StatusChip'
export type { StatusChipProps } from './StatusChip'

export { TipoChip } from './TipoChip'
export type { TipoChipProps } from './TipoChip'

export { OrigemChip } from './OrigemChip'
export type { OrigemChipProps } from './OrigemChip'

export { ContaBadge } from './ContaBadge'
export type { ContaBadgeProps } from './ContaBadge'

export { Donut } from './Donut'
export type { DonutProps, DonutDatum } from './Donut'

export { BarChart } from './BarChart'
export type { BarChartProps, BarGroup } from './BarChart'

export { ProgressBar } from './ProgressBar'
export type { ProgressBarProps } from './ProgressBar'

export { default as QuickActions } from './QuickActions'
export type { QuickActionsProps, QuickActionKey } from './QuickActions'

export { FinIcon, hasFinIcon } from './finIcons'
export type { FinIconProps } from './finIcons'

export { FIN_SERIES_COLORS, FIN_NEUTRAL_COLOR, hexToRgba, seriesColor } from './utils'
