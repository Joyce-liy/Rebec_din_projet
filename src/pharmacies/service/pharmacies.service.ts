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

  async findAll() {
    return this.pharmacieRepository.find();
  }

    async findNearby(lat: number, lng: number, radius: number) {
    console.log('PARAMS REÇUS DANS LE SERVICE →', {
      lat,
      lng,
      radius,
    });

    return this.pharmacieRepository.query(
      `
      SELECT
        id,
        nom,
        adresse,
        telephone,
        ST_Distance(
          localisation,
          ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
        ) AS distance_m
      FROM pharmacies
      WHERE ST_DWithin(
        localisation,
        ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
        $3
      )
      ORDER BY distance_m ASC
      `,
      [
        Number(lng),   // ⚠️ longitude en premier
        Number(lat),   // ⚠️ latitude en second
        Number(radius)
      ],
    );
  }

}
