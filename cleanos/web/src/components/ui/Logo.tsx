interface LogoProps {
  size?: number
  showText?: boolean
  showSub?: boolean
}

export function Logo({ size = 36, showText = true, showSub = false }: LogoProps) {
  return (
    <div className="clx-logo">
      <div
        className="clx-logo-mark"
        style={{ width: size, height: size, fontSize: `${size * 0.42}px` }}
        aria-hidden="true"
      >
        C
      </div>
      {showText && (
        <div>
          <span className="clx-logo-text">CleanOS</span>
          {showSub && <span className="clx-logo-sub">by Cleanox</span>}
        </div>
      )}
    </div>
  )
}
