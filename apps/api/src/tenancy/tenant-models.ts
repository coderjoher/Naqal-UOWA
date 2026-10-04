/** Models carrying `universityId` that are always filtered by the current tenant (NF-05). */
export const TENANT_MODELS: ReadonlySet<string> = new Set(['User', 'AuditEvent']);
