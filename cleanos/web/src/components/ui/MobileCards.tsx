const AVATAR_COLORS = [
  '#00A39B',
  '#0F4C5C',
  '#2563EB',
  '#7C3AED',
  '#D97706',
  '#16A34A',
  '#DC2626',
  '#DB2777',
  '#0E7490',
  '#9333EA',
]

export function avatarColor(name: string): string {
  let hash = 0
  for (let i = 0; i < name.length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash)
  }
  return AVATAR_COLORS[Math.abs(hash) % AVATAR_COLORS.length]
}

export function CardAvatar({ name }: { name: string }) {
  const initial = name ? name.charAt(0).toUpperCase() : '?'
  return (
    <div className="mob-card-avatar" style={{ background: avatarColor(name) }}>
      {initial}
    </div>
  )
}
