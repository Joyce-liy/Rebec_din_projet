#!/bin/bash
# Résoudre tous les conflits en acceptant les changements de l'autre branche
git checkout --theirs .
git add .
git commit -m "Résolution des conflits: acceptation des changements de l'autre branche"
echo "Conflits résolus avec succès!"
