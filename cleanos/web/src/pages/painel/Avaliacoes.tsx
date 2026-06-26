import { useCallback, useEffect, useRef, useState } from 'react'
import { pb } from '../../lib/pb'
import {
  COLLECTIONS,
  type User,
  type OrdemServico,
  formatDateTime,
  userDisplayName,
} from '../../lib/collections'
import { StarRating } from '../../components/ui/StarRating'
import { Spinner } from '../../components/ui/Spinner'
import { IconAlertCircle, IconChevronDown } from '../../components/ui/Icon'

const PAGE_SIZE = 5

interface RatingStats {
  media: number
  total: number
}

export default function Avaliacoes() {
  const [profissionais, setProfissionais] = useState<User[]>([])
  const [ratingMap, setRatingMap] = useState<Record<string, RatingStats>>({})
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const [openId, setOpenId] = useState<string | null>(null)
  const [reviews, setReviews] = useState<OrdemServico[]>([])
  const [reviewsPage, setReviewsPage] = useState(1)
  const [reviewsTotal, setReviewsTotal] = useState(0)
  const [reviewsLoading, setReviewsLoading] = useState(false)
  const [reviewsError, setReviewsError] = useState<string | null>(null)

  const reviewsFetchKeyRef = useRef<string | null>(null)

  const load = useCallback(async () => {
    try {
      setLoading(true)
      setError(null)
      const [profs, osAvaliadas] = await Promise.all([
        pb.collection(COLLECTIONS.USERS).getFullList<User>({
          filter: "role = 'profissional'",
          sort: 'name',
        }),
        pb.collection(COLLECTIONS.ORDENS_SERVICO).getFullList<OrdemServico>({
          filter: 'avaliacao_nota >= 1',
          fields: 'id,profissional,avaliacao_nota',
        }),
      ])

      const acc: Record<string, { soma: number; total: number }> = {}
      for (const os of osAvaliadas) {
        if (os.profissional && os.avaliacao_nota != null) {
          if (!acc[os.profissional]) acc[os.profissional] = { soma: 0, total: 0 }
          acc[os.profissional].soma += os.avaliacao_nota
          acc[os.profissional].total += 1
        }
      }
      const rm: Record<string, RatingStats> = {}
      for (const [id, { soma, total }] of Object.entries(acc)) {
        rm[id] = { media: soma / total, total }
      }

      profs.sort((a, b) => {
        const ra = rm[a.id]
        const rb = rm[b.id]
        if (ra && rb) return rb.media - ra.media
        if (ra) return -1
        if (rb) return 1
        return (a.name ?? '').localeCompare(b.name ?? '')
      })

      setProfissionais(profs)
      setRatingMap(rm)
    } catch {
      setError('Não foi possível carregar os profissionais.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  async function loadReviews(profId: string, page: number, reset: boolean) {
    reviewsFetchKeyRef.current = profId
    try {
      setReviewsLoading(true)
      setReviewsError(null)
      const result = await pb.collection(COLLECTIONS.ORDENS_SERVICO).getList<OrdemServico>(
        page,
        PAGE_SIZE,
        {
          filter: `profissional = '${profId}' && avaliacao_nota >= 1`,
          sort: '-avaliacao_em',
        },
      )
      if (reviewsFetchKeyRef.current !== profId) return
      setReviewsTotal(result.totalItems)
      setReviews((prev) => reset ? result.items : [...prev, ...result.items])
      setReviewsPage(page)
    } catch {
      if (reviewsFetchKeyRef.current === profId) {
        setReviewsError('Não foi possível carregar as avaliações.')
      }
    } finally {
      if (reviewsFetchKeyRef.current === profId) setReviewsLoading(false)
    }
  }

  function handleToggle(profId: string) {
    if (openId === profId) {
      setOpenId(null)
      setReviews([])
      setReviewsPage(1)
      setReviewsTotal(0)
    } else {
      setOpenId(profId)
      setReviews([])
      setReviewsPage(1)
      setReviewsTotal(0)
      loadReviews(profId, 1, true)
    }
  }

  function handleLoadMore() {
    if (!openId) return
    loadReviews(openId, reviewsPage + 1, false)
  }

  const hasMore = reviews.length < reviewsTotal

  return (
    <div>
      <div className="page-toolbar">
        <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={load} style={{ marginLeft: 'auto' }}>
          Atualizar
        </button>
      </div>

      {error && (
        <div className="error-banner" role="alert">
          <IconAlertCircle size={16} /> {error}
        </div>
      )}

      {loading ? (
        <div className="loading-overlay"><Spinner size={22} /> Carregando profissionais…</div>
      ) : profissionais.length === 0 ? (
        <div className="table-wrap">
          <div className="empty-state">
            <h4>Nenhum profissional cadastrado</h4>
            <p>Cadastre profissionais na tela de Usuários.</p>
          </div>
        </div>
      ) : (
        <div className="table-wrap">
          {profissionais.map((prof) => {
            const stats = ratingMap[prof.id]
            const isOpen = openId === prof.id
            const hasRatings = !!stats

            return (
              <div key={prof.id} className="accordion-item">
                <button
                  className={`accordion-header${isOpen ? ' open' : ''}`}
                  onClick={() => hasRatings && handleToggle(prof.id)}
                  aria-expanded={isOpen}
                  style={!hasRatings ? { cursor: 'default' } : undefined}
                >
                  <div className="accordion-header-left">
                    <span className="accordion-prof-name">{userDisplayName(prof)}</span>
                    {hasRatings ? (
                      <span className="accordion-rating">
                        <StarRating nota={Math.round(stats.media)} size={14} />
                        <span className="accordion-rating-text">
                          {stats.media.toFixed(1)} ({stats.total} avaliação{stats.total !== 1 ? 'ões' : ''})
                        </span>
                      </span>
                    ) : (
                      <span className="accordion-no-rating">sem avaliações ainda</span>
                    )}
                  </div>
                  {hasRatings && (
                    <span className={`accordion-chevron${isOpen ? ' open' : ''}`}>
                      <IconChevronDown size={16} />
                    </span>
                  )}
                </button>

                {isOpen && (
                  <div className="accordion-body">
                    {reviewsError && (
                      <div className="error-banner" role="alert" style={{ margin: '0 0 12px' }}>
                        <IconAlertCircle size={14} /> {reviewsError}
                      </div>
                    )}

                    {reviews.length === 0 && !reviewsLoading ? (
                      <div style={{ padding: '16px 0', color: 'var(--clx-ink-3)', fontSize: '0.875rem' }}>
                        Nenhuma avaliação encontrada.
                      </div>
                    ) : (
                      <div className="review-list">
                        {reviews.map((os) => (
                          <div key={os.id} className="review-card">
                            <div className="review-card-header">
                              <StarRating nota={os.avaliacao_nota!} size={15} />
                              <span className="review-date">{formatDateTime(os.avaliacao_em ?? '')}</span>
                            </div>
                            <div className="review-meta">
                              <span>{os.tipo_servico_nome ?? '—'}</span>
                              <span className="review-meta-sep">·</span>
                              <span>{os.nome_curto}</span>
                              <span className="review-meta-sep">·</span>
                              <span>{formatDateTime(os.data_hora)}</span>
                            </div>
                            {os.avaliacao_motivo ? (
                              <p className="review-motivo">{os.avaliacao_motivo}</p>
                            ) : os.avaliacao_nota != null && os.avaliacao_nota <= 3 ? (
                              <p className="review-motivo review-motivo-empty">sem comentário</p>
                            ) : null}
                          </div>
                        ))}
                      </div>
                    )}

                    {reviewsLoading && (
                      <div style={{ display: 'flex', justifyContent: 'center', padding: '12px 0' }}>
                        <Spinner size={18} />
                      </div>
                    )}

                    {!reviewsLoading && hasMore && (
                      <div style={{ display: 'flex', justifyContent: 'center', padding: '12px 0 4px' }}>
                        <button className="clx-btn clx-btn-ghost clx-btn-sm" onClick={handleLoadMore}>
                          Ver mais
                        </button>
                      </div>
                    )}
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
