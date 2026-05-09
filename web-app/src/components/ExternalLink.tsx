import { ExternalLink as ExternalLinkIcon } from 'lucide-react'
import type { AnchorHTMLAttributes, ReactNode } from 'react'

type ExternalLinkProps = Omit<
  AnchorHTMLAttributes<HTMLAnchorElement>,
  'href' | 'target' | 'rel'
> & {
  href: string
  children?: ReactNode
  iconClassName?: string
  withIcon?: boolean
  iconSize?: number
}

export default function ExternalLink({
  href,
  className = '',
  children,
  iconClassName = 'shrink-0 opacity-70',
  withIcon = true,
  iconSize = 14,
  ...rest
}: ExternalLinkProps) {
  return (
    <a
      {...rest}
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className={`inline-flex items-center gap-1.5 ${className}`.trim()}
    >
      {children}
      {withIcon ? (
        <ExternalLinkIcon
          className={iconClassName}
          size={iconSize}
          aria-hidden
        />
      ) : null}
    </a>
  )
}
