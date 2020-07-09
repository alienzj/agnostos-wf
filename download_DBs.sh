#!/bin/#!/usr/bin/env bash

mkdir -p databases

cd databases

# Pfam database
wget ftp://ftp.ebi.ac.uk/pub/databases/Pfam/releases/Pfam31.0/Pfam-A.hmm.gz
gunzip Pfam-A.hmm.gz

# Pfam clans
wget ftp://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.clans.tsv.gz

# Pfam HHBLITS DB
wget http://wwwuser.gwdg.de/~compbiol/data/hhsuite/databases/hhsuite_dbs/pfamA_31.0.tgz
tar xvfz pfamA_31.0.tgz

# Pfam list common domain terms
wget https://ndownloader.figshare.com/files/23756204 -O Pfam-31_names_mod_01122019.tsv

# Antifam databases
wget ftp://ftp.ebi.ac.uk/pub/databases/Pfam/AntiFam/current/Antifam.tar.gz
tar xvfz Antifam.tar.gz
../bin/hmmpress AntiFam.hmm

# Uniref90
wget ftp://ftp.uniprot.org/pub/databases/uniprot/uniref/uniref90/uniref90.fasta.gz

# NCBI nr
wget ftp://ftp.ncbi.nih.gov/blast/db/FASTA/nr.gz
mv nr.gz nr.fasta.gz

# Uniclust HHBLITS DB
wget http://wwwuser.gwdg.de/~compbiol/uniclust/2018_08/uniclust30_2018_08.tar.gz
tar xvfz uniclust30_2018_08.tar.gz

# DPD and info
wget https://ndownloader.figshare.com/files/23756312 -O dpd_uniprot_sprot.fasta.gz
wget https://ndownloader.figshare.com/files/23756306 -O dpd_ids_all_info.tsv.gz

# Uniprot KB
# wget ftp://ftp.expasy.org/databases/uniprot/current_release/knowledgebase/complete/uniprot_trembl.fasta.gz
# wget wget ftp://ftp.expasy.org/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz
# zcat uniprot_trembl.fasta.gz uniprot_sprot.fasta.gz | gzip > uniprotKB.fasta.gz
# rm uniprot_trembl.fasta.gz uniprot_sprot.fasta.gz

# NCBI Taxonomy
# mkdir ncbi-taxdump && cd ncbi-taxdump
# wget ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
# tar xzvf taxdump.tar.gz
# cd ..

cd ..
