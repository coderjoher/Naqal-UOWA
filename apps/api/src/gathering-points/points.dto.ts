import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsLatitude, IsLongitude, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class CreatePointDto {
  @ApiProperty() @IsString() @MaxLength(120) name: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(120) nameAr?: string;
  @ApiProperty() @IsLatitude() lat: number;
  @ApiProperty() @IsLongitude() lng: number;
  /** Set to override the automatic tier. */
  @ApiPropertyOptional() @IsOptional() @IsUUID() tierId?: string;
}

export class UpdatePointDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(120) name?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(120) nameAr?: string;
  @ApiPropertyOptional() @IsOptional() @IsLatitude() lat?: number;
  @ApiPropertyOptional() @IsOptional() @IsLongitude() lng?: number;
  /** A tier id overrides; `null` returns to the automatic tier. */
  @ApiPropertyOptional({ nullable: true }) @IsOptional() @IsUUID() tierId?: string | null;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() active?: boolean;
}
