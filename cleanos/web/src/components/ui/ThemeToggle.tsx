import { useTheme } from '../../contexts/ThemeContext'
import { IconSun, IconMoon } from './Icon'

export function ThemeToggle({ size = 18 }: { size?: number }) {
  const { theme, toggle } = useTheme()
  const isDark = theme === 'dark'
  return (
    <button
      className="icon-btn"
      onClick={toggle}
      aria-label={isDark ? 'Ativar modo claro' : 'Ativar modo escuro'}
      title={isDark ? 'Modo claro' : 'Modo escuro'}
      style={{ color: isDark ? 'var(--clx-warning)' : 'var(--clx-ink-3)' }}
    >
      {isDark ? <IconSun size={size} /> : <IconMoon size={size} />}
    </button>
  )
}
