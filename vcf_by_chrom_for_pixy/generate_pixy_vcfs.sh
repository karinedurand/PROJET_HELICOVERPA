#!/bin/bash

#SBATCH --partition=dgimi-eha
#SBATCH --job-name=pixy_pipeline
#SBATCH --output=pixy_pipeline.out
#SBATCH --error=pixy_pipeline.err
#SBATCH --mem=60G

set -euo pipefail
source /home/durandk/miniconda3/etc/profile.d/conda.sh
conda activate bcftools

# ----------------------------
# Paths and parameters
# ----------------------------
GATK="/storage/simple/projects/faw_adaptation/programs/gatk-4.1.2.0/gatk"
REF="/lustre/durandk/HELICOVERPA/ref_HZEA/GCF_022581195.2_ilHelZeax1.1_genomic.fna"
BAM_DIR="/lustre/durandk/HELICOVERPA/VariantCalling/Variant_calling_HZ"
GVCF_DIR="/lustre/durandk/HELICOVERPA/VCF"
MERGED_GVCF="/storage/simple/projects/faw_adaptation/Data_Backup/Lepidoptera_SNP/Helicoverpa_PROJET/Helicoverpa_zea_PRJNA825115_n237/VCF/Pixy_vcf/merged.g.vcf.gz"
OUT_DIR="/lustre/durandk/HELICOVERPA/NORTH/chromosome_vcfs_pixy"
CHROM_LIST="/lustre/durandk/HELICOVERPA/NORTH/chrom.list"

mkdir -p "$GVCF_DIR"
mkdir -p "$OUT_DIR"

# ----------------------------
# Step 1: HaplotypeCaller per BAM file
# ----------------------------
echo ">>> Step 1: Generating individual .g.vcf.gz files"
for BAM in "$BAM_DIR"/*.bam; do
    SAMPLE=$(basename "$BAM" .bam)
    OUT_GVCF="${GVCF_DIR}/${SAMPLE}.g.vcf.gz"
    
    if [[ ! -f "$OUT_GVCF" ]]; then
        echo "Calling variants for $SAMPLE"
        $GATK HaplotypeCaller \
            -R "$REF" \
            -I "$BAM" \
            -O "$OUT_GVCF" \
            -ERC GVCF
    else
        echo "Already exists: $OUT_GVCF"
    fi
done

# ----------------------------
# Step 2: Merge all GVCFs
# ----------------------------
echo ">>> Step 2: Merging all individual GVCFs"
MERGE_CMD="$GATK CombineGVCFs -R $REF -O $MERGED_GVCF"
for GVCF in "$GVCF_DIR"/*.g.vcf.gz; do
    MERGE_CMD="$MERGE_CMD --variant $GVCF"
done

echo "Running merge command..."
eval "$MERGE_CMD"

# ----------------------------
# Step 3: GenotypeGVCFs --all-sites per chromosome
# ----------------------------
echo ">>> Step 3: Generating all-sites VCFs for pixy per chromosome"

while read -r CHR; do
    echo "Processing chromosome: $CHR"
    OUT_VCF="${OUT_DIR}/${CHR}.pixy.vcf.gz"

    $GATK GenotypeGVCFs \
        -R "$REF" \
        -V "$MERGED_GVCF" \
        -L "$CHR" \
        --all-sites \
        -O "$OUT_VCF"

    /storage/simple/projects/faw_adaptation/programs/htslib-1.9/tabix -p vcf "$OUT_VCF"
    echo "→ VCF ready for pixy: $OUT_VCF"

done < "$CHROM_LIST"
