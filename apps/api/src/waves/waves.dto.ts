import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsInt, IsOptional, Matches, Max, Min } from 'class-validator';

export class CreateWaveDto {
  @ApiProperty({ enum: ['morning', 'return'] }) @IsIn(['morning', 'return']) type: 'morning' | 'return';
  @ApiProperty({ example: '08:00' }) @Matches(/^([01]\d|2[0-3]):([0-5]\d)$/) time: string;
  @ApiProperty({ description: 'Bit mask, bit 0 = Sunday … bit 6 = Saturday' }) @IsInt() @Min(1) @Max(127) weekdays: number;
}

export class UpdateWaveDto {
  @ApiPropertyOptional() @IsOptional() @Matches(/^([01]\d|2[0-3]):([0-5]\d)$/) time?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(127) weekdays?: number;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() active?: boolean;
}
