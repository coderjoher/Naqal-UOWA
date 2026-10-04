import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsEmail, IsInt, IsLatitude, IsLongitude, IsNumber, IsOptional, IsString, Matches, Max, MaxLength, Min, MinLength, ValidateNested } from 'class-validator';

export class OfficeAccountDto {
  @ApiProperty() @IsString() @MaxLength(120) name: string;
  @ApiProperty() @IsEmail() email: string;
  @ApiProperty() @IsString() @MinLength(10) password: string;
}

export class CreateUniversityDto {
  @ApiProperty() @IsString() @MaxLength(200) name: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) nameAr?: string;
  @ApiProperty() @Matches(/^[a-z0-9-]{2,40}$/) slug: string;
  @ApiProperty() @IsLatitude() campusLat: number;
  @ApiProperty() @IsLongitude() campusLng: number;
  @ApiPropertyOptional({ description: 'Service area polygon as [[lat, lng], ...]' })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(500)
  coverage?: [number, number][];
  @ApiPropertyOptional({ description: 'Commission %, 0–100, two decimals' })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(100)
  commissionPct?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(240) waitlistMinutes?: number;
  @ApiPropertyOptional({ type: OfficeAccountDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => OfficeAccountDto)
  officeAccount?: OfficeAccountDto;
}

export class UpdateUniversityDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) name?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) nameAr?: string;
  @ApiPropertyOptional() @IsOptional() @IsLatitude() campusLat?: number;
  @ApiPropertyOptional() @IsOptional() @IsLongitude() campusLng?: number;
  @ApiPropertyOptional() @IsOptional() @IsArray() @ArrayMaxSize(500) coverage?: [number, number][];
  @ApiPropertyOptional() @IsOptional() @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) @Max(100) commissionPct?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) @Max(240) waitlistMinutes?: number;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(300) officeNote?: string;
}
