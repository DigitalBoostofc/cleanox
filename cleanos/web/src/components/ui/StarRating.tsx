/** Exibe estrelas read-only para avaliação 1–5. */
export function StarRating({ nota, size = 14 }: { nota: number; size?: number }) {
  return (
    <span
      role="img"
      aria-label={`${nota} de 5 estrelas`}
      style={{ display: 'inline-flex', gap: 1, lineHeight: 1, verticalAlign: 'middle' }}
    >
      {[1, 2, 3, 4, 5].map((i) => (
        <span
          key={i}
          style={{ fontSize: size, color: i <= nota ? '#f59e0b' : 'var(--clx-line)' }}
        >
          ★
        </span>
      ))}
    </span>
  )
}
