import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Pharmacie } from '../entity/pharmacie.entity';

@Injectable()
export class PharmaciesService {
  constructor(
    @InjectRepository(Pharmacie)
    private pharmacieRepository: Repository<Pharmacie>,
  ) {}

  async create(data: {
    nom: string;
    adresse?: string;
    telephone?: string;
    whatsapp?: string;
    latitude: number;
    longitude: number;
  }) {
    const pharmacie = this.pharmacieRepository.create({
      nom: data.nom,
      adresse: data.adresse,
      telephone: data.telephone,
      whatsapp: data.whatsapp,
      localisation: {
        type: 'Point',
        coordinates: [data.longitude, data.latitude],
      },
    });

    return this.pharmacieRepository.save(pharmacie);
  }
}
