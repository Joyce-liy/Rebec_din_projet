import { IsString, IsNumber, IsOptional } from 'class-validator';

export class CreatePharmacieDto {
  @IsString()
  nom: string;

  @IsOptional()
  @IsString()
  adresse?: string;

  @IsOptional()
  @IsString()
  telephone?: string;

  @IsOptional()
  @IsString()
  whatsapp?: string;

  @IsNumber()
  latitude: number;

  @IsNumber()
  longitude: number;
}
