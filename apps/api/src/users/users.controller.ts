import { Controller, Get, NotFoundException, Param, ParseUUIDPipe } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser, Roles } from '../auth/decorators';
import { PrismaService } from '../prisma/prisma.service';

const PUBLIC_FIELDS = { id: true, name: true, email: true, phone: true, role: true, gender: true, status: true, universityId: true } as const;

@ApiTags('users')
@ApiBearerAuth()
@Controller()
export class UsersController {
  constructor(private readonly prisma: PrismaService) {}

  /** Office: users of its own university only (tenant filter applied by Prisma extension). */
  @Roles('office')
  @Get('users')
  list() {
    return this.prisma.db.user.findMany({ select: PUBLIC_FIELDS, orderBy: { createdAt: 'asc' } });
  }

  @Roles('office')
  @Get('users/:id')
  async get(@Param('id', ParseUUIDPipe) id: string) {
    const user = await this.prisma.db.user.findUnique({ where: { id }, select: PUBLIC_FIELDS });
    if (!user) throw new NotFoundException();
    return user;
  }

  @Roles('student')
  @Get('students/me')
  student(@CurrentUser() user: AuthUser) {
    return this.get(user.id);
  }

  @Roles('driver')
  @Get('drivers/me')
  driver(@CurrentUser() user: AuthUser) {
    return this.get(user.id);
  }
}
