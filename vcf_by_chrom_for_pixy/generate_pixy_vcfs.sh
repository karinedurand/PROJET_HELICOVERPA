#!/bin/bash

#SBATCH --partition=dgimi-eha
#SBATCH --job-name=generate_pixy_vcfs
#SBATCH --output=generate_pixy_vcfs.out
#SBATCH --error=generate_pixy_vcfs.err
#SBATCH --mem=40G

set -euo pipefail
source /home/durandk/miniconda3/etc/profile.d/conda.sh
conda activate bcftools

module load  jre/jre.8_x64
# ----------------------------
# Chemins à adapter si besoin
# ----------------------------
GATK="/storage/simple/projects/faw_adaptation/programs/gatk-4.1.2.0/gatk"
REF="/lustre/durandk/HELICOVERPA/ref_HZEA/GCF_022581195.2_ilHelZeax1.1_genomic.fna"
MERGED_GVCF="/storage/simple/projects/faw_adaptation/Data_Backup/Lepidoptera_SNP/Helicoverpa_PROJET/Helicoverpa_zea_PRJNA825115_n237/VCF/Pixy_vcf/merged.g.vcf.gz"
OUT_DIR="/lustre/durandk/HELICOVERPA/NORTH/chromosome_vcfs"

mkdir -p "$OUT_DIR"

# ----------------------------
# Boucle sur chaque chromosome
# ----------------------------
while read -r CHR; do
    echo "Traitement du chromosome $CHR"

    RAW_VCF="${OUT_DIR}/${CHR}.vallsites.vcf.gz"
    SNP_VCF="${OUT_DIR}/${CHR}.snps.vcf.gz"
    SNP_PASS_VCF="${OUT_DIR}/${CHR}.snps.pass.vcf.gz"
    REF_VCF="${OUT_DIR}/${CHR}.ref.vcf.gz"
    FINAL_VCF="${OUT_DIR}/${CHR}.pixy.filtered.vcf.gz"

    # Étape 1 : GenotypeGVCFs avec --all-sites
    $GATK GenotypeGVCFs \
        -R "$REF" \
        -V "$MERGED_GVCF" \
        -L NC_061470.1 \
        --all-sites \
        -O "${OUT_DIR}/NC_061470.1.vallsites.vcf.gz"

    # Étape 2 : Séparer SNPs et invariants
    bcftools view -v snps "$RAW_VCF" -O z -o "$SNP_VCF"
    bcftools view -v ref "$RAW_VCF" -O z -o "$REF_VCF"

    # Étape 3 : Filtrer SNPs (plus strict)
    bcftools view -f PASS "$SNP_VCF" -O z -o "$SNP_PASS_VCF"
    /storage/simple/projects/faw_adaptation/programs/vcftools_0.1.13/bin/vcftools --gzvcf "$SNP_PASS_VCF" \
        --remove-indels \
        --max-missing 0.8 \
        --min-meanDP 10 \
        --max-meanDP 500 \
        --recode --stdout | /storage/simple/projects/faw_adaptation/programs/htslib-1.9/bgzip -c > "${OUT_DIR}/${CHR}.filtered_snps.vcf.gz"

    # Étape 4 : Filtrer invariants (plus permissif)
    /storage/simple/projects/faw_adaptation/programs/vcftools_0.1.13/bin/vcftools --gzvcf "$REF_VCF" \
        --max-missing 0.5 \
        --min-meanDP 10 \
        --max-meanDP 500 \
        --recode --stdout | /storage/simple/projects/faw_adaptation/programs/htslib-1.9/bgzip -c > "${OUT_DIR}/${CHR}.filtered_ref.vcf.gz"

    # Étape 5 : Concaténer SNPs + invariants
    bcftools concat "${OUT_DIR}/${CHR}.filtered_snps.vcf.gz" "${OUT_DIR}/${CHR}.filtered_ref.vcf.gz" \
        -O z -o "$FINAL_VCF"

    # Étape 6 : Indexation pour Pixy
    /storage/simple/projects/faw_adaptation/programs/htslib-1.9/tabix -p vcf "$FINAL_VCF"

    # Nettoyage intermédiaire (optionnel)
    rm "$SNP_VCF" "$SNP_PASS_VCF" "$REF_VCF" "${OUT_DIR}/${CHR}.filtered_snps.vcf.gz" "${OUT_DIR}/${CHR}.filtered_ref.vcf.gz"

    echo "→ Fichier prêt : $FINAL_VCF"

done < /lustre/durandk/HELICOVERPA/NORTH/chrom.list

