import { HttpApiConfig, HttpApiProvider } from './http-api.provider';
import { IdentityProvider } from './identity-provider';
import { OidcConfig, OidcProvider } from './oidc.provider';
import { RosterProvider, RosterStore } from './roster.provider';

export type IdentityConfig = { type: 'manual' } | HttpApiConfig | OidcConfig;

/** Reads `integrationConfig.identity`; defaults to the manual roster so a pilot is never blocked (Q2). */
export function identityConfig(integrationConfig: unknown): IdentityConfig {
  const cfg = (integrationConfig as { identity?: IdentityConfig } | null)?.identity;
  if (cfg && (cfg.type === 'http' || cfg.type === 'oidc')) return cfg;
  return { type: 'manual' };
}

export function createIdentityProvider(cfg: IdentityConfig, roster: RosterStore): IdentityProvider {
  switch (cfg.type) {
    case 'http':
      return new HttpApiProvider(cfg);
    case 'oidc':
      return new OidcProvider(cfg);
    default:
      return new RosterProvider(roster);
  }
}
