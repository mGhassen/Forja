import { createFileRoute } from '@tanstack/react-router'

export type ApiRouteHandler = (ctx: {
  request: Request
}) => Response | Promise<Response>

/** Route tree typings omit `server` handlers until TanStack codegen catches up. */
export function defineApiRoute(
  path: string,
  handlers: Record<string, ApiRouteHandler>,
) {
  const create = createFileRoute as (p: string) => (options: Record<string, unknown>) => unknown
  return create(path)({
    server: { handlers },
  })
}
