export type Role = 'student' | 'driver' | 'office' | 'super_admin';

export interface SessionUser {
  id: string;
  name: string;
  role: Role;
  universityId: string | null;
}

export interface Session {
  accessToken: string;
  user: SessionUser;
}

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
    /** Validation / business messages from the API body, if any. */
    public messages: string[] = [],
  ) {
    super(message);
  }
}

export const API_URL: string = import.meta.env.VITE_API_URL ?? '/api';
const SESSION_KEY = 'naql.session';

export function loadSession(): Session | null {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    return raw ? (JSON.parse(raw) as Session) : null;
  } catch {
    return null;
  }
}

export function saveSession(s: Session | null) {
  try {
    if (s) localStorage.setItem(SESSION_KEY, JSON.stringify(s));
    else localStorage.removeItem(SESSION_KEY);
  } catch {
    /* private mode */
  }
}

/** Fetch wrapper: adds the bearer token, parses JSON, throws ApiError on non-2xx. */
export async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const session = loadSession();
  const res = await fetch(`${API_URL}${path}`, {
    ...init,
    headers: {
      'content-type': 'application/json',
      ...(session ? { authorization: `Bearer ${session.accessToken}` } : {}),
      ...init.headers,
    },
  });
  if (res.status === 401 && session) {
    saveSession(null);
    window.dispatchEvent(new Event('naql:logout'));
  }
  if (!res.ok) {
    let messages: string[] = [];
    try {
      const body = (await res.json()) as { message?: string | string[] };
      messages = Array.isArray(body.message) ? body.message : body.message ? [body.message] : [];
    } catch {
      /* no JSON body */
    }
    throw new ApiError(res.status, res.statusText, messages);
  }
  return (await res.json()) as T;
}
