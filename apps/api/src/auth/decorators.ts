import { SetMetadata, createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { Role } from '@prisma/client';

export const IS_PUBLIC = 'isPublic';
export const ROLES = 'roles';

/** Route needs no authentication. */
export const Public = () => SetMetadata(IS_PUBLIC, true);
/** Route is limited to these roles. Without it any authenticated user may call it. */
export const Roles = (...roles: Role[]) => SetMetadata(ROLES, roles);

export interface AuthUser {
  id: string;
  role: Role;
  universityId: string | null;
}

export const CurrentUser = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): AuthUser => ctx.switchToHttp().getRequest().user,
);
