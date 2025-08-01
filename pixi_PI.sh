#!/bin/bash
#SBATCH --partition=dgimi-eha
#SBATCH -c 4
pixy --vcf /lustre/durandk/HELICOVERPA/PCA/EIGENSOFT/HZR_0.2.rename.recode.vcf.gz \
     --populations meta metadata_HZR_36.txt \
     --stats pi \
     --window_size 10000 \
     --output_prefix HZR_Pi



# pixy --stats pi fst dxy \
# --vcf data/vcf/ag1000/chrX_36Ag_allsites.vcf.gz \
# --populations data/vcf/ag1000/Ag1000_sampleIDs_popfile.txt \
# --window_size 10000 \
# --n_cores 4 \
# --chromosomes 'X'