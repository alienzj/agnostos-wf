rule cluster_refinement:
      input:
        good = config["rdir"] + "/validation/good_clusters.tsv",
        val_res = config["rdir"] + "/validation/validation_results.tsv",
        sp_sh = config["rdir"] + "/spurious_shadow/spurious_shadow_info.tsv",
        cval_rej = config["rdir"] + "/compositional_validation/compositional_validation_rejected_orfs.tsv"
      threads: 28
      params:
        mmseqs_bin = config["mmseqs_bin"],
        mpi_runner = config["mpi_runner"],
        good_noshadow = config["rdir"] + "/cluster_refinement/good_noshadow_clusters.txt",
        cluseqdb = config["rdir"] + "/mmseqs_clustering/new_clu_seqDB",
        clu_info = config["rdir"] + "/mmseqs_clustering/cluDB_info.tsv",
        partial = config["rdir"] + "/gene_prediction/orf_partial_info.tsv",
        name_index = config["rdir"] + "/mmseqs_clustering/new_cluDB_name_index.txt",
        tmpdb = config["rdir"] + "/cluster_refinement/clu_good_noshadow_seqDB",
        rej = config["rdir"] + "/cluster_refinement/clu_good_noshadow_rejected_orfs.txt",
        toremove = config["rdir"] + "/cluster_refinement/orfs_to_remove.txt",
        toremove_cl = config["rdir"] + "/cluster_refinement/cluster_orfs_to_remove.tsv",
        toremove_sh = "scripts/remove_orfs.sh",
        refdb = config["rdir"] + "/cluster_refinement/refined_clusterDB",
        refdb_annot = config["rdir"] + "/cluster_refinement/refined_annotated_clusterDB",
        refdb_noannot = config["rdir"] + "/cluster_refinement/refined_not_annotated_clusterDB",
        annot = config["rdir"] + "/annot_and_clust/annotated_clusters.tsv",
        noannot = config["rdir"] + "/annot_and_clust/not_annotated_clusters.tsv",
        new_noannot = config["rdir"] + "/cluster_refinement/new_not_annotated_clusters.tsv",
        tmp = config["rdir"] + "/cluster_refinement/refined_tmp",
        tmp1 = config["rdir"] + "/cluster_refinement/refined_tmp1",
        tmp2 = config["rdir"] + "/cluster_refinement/refined_tmp2",
        tmp3 = config["rdir"] + "/cluster_refinement/refined_tmp3",
        tmp4 = config["rdir"] + "/cluster_refinement/refined_tmp4",
        tmp5 = config["rdir"] + "/cluster_refinement/refined_tmp5"
      output:
        ref_clu = config["rdir"] + "/cluster_refinement/refined_clusters.tsv",
        ref_annot = config["rdir"] + "/cluster_refinement/refined_annotated_clusters.tsv",
        ref_noannot = config["rdir"] + "/cluster_refinement/refined_not_annotated_clusters.tsv"
      log:
        out = "logs/cl_ref_stdout.log",
        err = "logs/cl_ref_stderr.err"
      benchmark:
        "benchmarks/cluster_refinement/cl_ref.tsv"
      shell:
        """
        set -x
        set -e

        # Step performed after the cluster validation, to remove:
        # 1. bad clusters (≥ 10% bad-aligned ORFs)
        # 2. shadow clusters (≥ 30% shadow ORFs)
        # 3. single rejected ORFs (shadow, spurious and bad-aligned)

        # 1st step: from the validation results we already have a table with the good clusters:
        # good_clusters.tsv (in the directory with the validation results)= {input.good}

        # 2nd step: we remove from the good clusters those with ≥ 30% shadows
        join -11 -21 -v2 <(awk '$5>=0.3 && !seen[$2]++{{print $2}}' {input.sp_sh} | sort -k1,1) \
          <( grep -v 'cl_name' {input.good} | awk '{{print $1}}' | sort -k1,1) > {params.good_noshadow}

        # Retrieve the subdb with the ORFs of these clusters
        # Need to use the converion table (MMseqs-index - Cluster-name)
        join -12 -21 <(sort -k2,2 {params.name_index}) <(sort -k1,1 {params.good_noshadow}) > {params.tmp}

        {params.mmseqs_bin} createsubdb <(awk '{{print $2}}' {params.tmp}) {params.cluseqdb} {params.tmpdb}

        # 3rd step: retrieve the single rejected/spurious/shadow ORFs and remove them from the remaining clusters

        # retrieve the bad-aligned sequences in the set of good & no-shadow clusters
        join -11 -21 <(sort -k1,1 {input.cval_rej} ) <(sort -k1,1 {params.good_noshadow}) > {params.rej}

        # Add the bad-aligned sequences to the spurious and shadows
        awk '$5<0.3 && $6!="FALSE"{{print $1}}' {input.sp_sh} > {params.toremove}
        awk '$5<0.3 && $7!="FALSE"{{print $1}}' {input.sp_sh} >> {params.toremove}
        awk '{{print $2}}' {params.rej} >> {params.toremove}

        if [[ -s {params.toremove} ]]; then
                # add cluster membership
                join -11 -21 <(sort {params.toremove}) \
                <(awk '{{print $3,$1}}' {params.clu_info} | sort -k1,1) \
                > {params.toremove_cl}

                # remove the single orfs from the clusters with less than 10% bad-aligned ORFs and less than 30% shadows.
                {params.mpi_runner} {params.mmseqs_bin} apply {params.tmpdb} {params.refdb} --threads {threads} \
                -- {params.toremove_sh} {params.toremove_cl} {params.name_index} 2>>{log.err} 1>>{log.out}

                # Create tables with new seqs and new clusters for some stats and checking the numbers
                join -11 -21 <(sort -k1,1 {params.name_index}) <(sort -k1,1 {params.refdb}.index) > {params.tmp}
                join -11 -21 <(awk '{{print $2}}' {params.tmp} | sort -k1,1) \
                    <(awk '{{print $1,$3}}' {params.clu_info} | sort -k1,1) > {params.tmp1}
                # Remove "bad" ORFs from the refined table
                join -12 -21 -v1 <(sort -k2,2 {params.tmp1}) \
                    <(sort -k1,1 {params.toremove}) > {params.tmp} && mv {params.tmp} {params.tmp1}
        else
          mv {params.good_noshadow} {params.tmp1}
        fi
        # From the refined clusters select the annotated and the not annotated for the following classification steps

        # annotated (check those left with no-annotated sequences): join with file with all annotated clusters (using the orfs)
        join -11 -21 <(sort -k1,1 {params.tmp1}) \
          <(awk '{{print $1,$3}}' {params.annot} \
          |  sort -k1,1) > {output.ref_annot}

        # Reorder columns to have cl_name - orf - pfam_name
        awk -vOFS='\\t' '{{print $2,$1,$3}}' {output.ref_annot} > {params.tmp} && mv {params.tmp} {output.ref_annot}

        # Find in the refiend annotated clusters, those left with no annotated ORFs
        sort -k1,1 {output.ref_annot} \
          | awk '!seen[$1,$3]++{{print $1,$3}}' \
          | awk 'BEGIN{{getline;id=$1;l1=$1;l2=$2;}}{{if($1 != id){{print l1,l2;l1=$1;l2=$2;}}else{{l2=l2"|"$2;}}id=$1;}}END{{print l1,l2;}}' \
          | grep -v "|" | awk '$2=="NA"{{print $1}}' > {params.new_noannot}

        if [[ -s {params.new_noannot} ]]; then

          # move the clusters left with no annotated member to the not annotated
          join -11 -21 -v1 <(awk '!seen[$1,$2,$3]++' {output.ref_annot} | sort -k1,1) \
            <(sort {params.new_noannot}) > {params.tmp}

          join -11 -21 <(awk '!seen[$1,$2,$3]++{{print $1,$2}}' {output.ref_annot} | sort -k1,1) \
            <(sort {params.new_noannot}) > {output.ref_noannot}

          # not annotated
          join -12 -21 <(sort -k2,2 {params.tmp1}) \
            <(awk -vFS='\\t' '$4=="noannot"{{print $1,$2}}' {input.good} | sort -k1,1) >> {output.ref_noannot}

          mv {params.tmp} {output.ref_annot}

        else

          # not annotated
          join -12 -21 <(sort -k2,2 {params.tmp1}) \
            <(awk '$4=="noannot"{{print $1,$2}}' {input.good} | sort -k1,1) > {output.ref_noannot}
        fi

        awk -vOFS='\\t' '{{print $1,$2}}' {output.ref_noannot} > {params.tmp} && mv {params.tmp} {output.ref_noannot}

        # Using the cluster ids retrieve the two sub database for annotated clusters and not
        # Again we need to use the MMseqs2 index instead of the Cluster names
        join -11 -22 <(awk '!seen[$1]++{{print $1}}' {output.ref_annot} | sort -k1,1) \
            <(sort -k2,2 {params.name_index}) > {params.tmp2}

        {params.mmseqs_bin} createsubdb <(awk '{{print $2}}' {params.tmp2}) \
                                        {params.refdb} \
                                        {params.refdb_annot} 2>>{log.err} 1>>{log.out}

        join -11 -22 <(awk '!seen[$1]++{{print $1}}' {output.ref_noannot} | sort -k1,1) \
            <(sort -k2,2 {params.name_index}) > {params.tmp3}

        {params.mmseqs_bin} createsubdb <(awk '{{print $2}}' {params.tmp3}) \
                                        {params.refdb} \
                                        {params.refdb_noannot} 2>>{log.err} 1>>{log.out}

        # Add ORF partial information to the refined cluster table
        # Colums partial: 1:orf|2:partial_info
        # Columns tmp3: 1:orf|2:partial_info|3:cl_name
        join -11 -21 <(sort -k1,1 {params.partial}) \
            <(sort -k1,1 {params.tmp1}) > {params.tmp3}

        # Add cluster size and ORF length
        # Columns clu_info: 1:cl_name|2:old_repr|3:orf|4:orf_len|5:cl_size
        # Columns intermediate: 1:orf|2:partial_info|3:cl_name|4:old_repr|5:cl_size|6:orf_len
        # Columns tmp4: 1:cl_name|2:orf|3:partial|4:cl_size|5:orf_len
        join -11 -21 <(sort -k1,1 {params.tmp3}) \
            <(awk '{{print $3,$2,$5,$4}}' {params.clu_info} | sort -k1,1) | sort -k3,3 | \
            awk -vOFS="\t" '{{print $3,$1,$2,$5,$6}}' > {params.tmp4}

        # Add new representatives from validation
        # Columns tmp5: 1:cl_name|2:orf|3:partial|4:cl_size|5:orf_len|6:new_repr
        join -11 -21 <(sort -k1,1 {params.tmp4}) \
            <(awk '{{print $1,$2}}' {input.val_res} | sort -k1,1) > {params.tmp5}

        # Reorder columns: 1:cl_name|2:new_repres|3:orf|4:cl_size|5:orf_length|6:partial
        awk -vOFS='\\t' '{{print $1,$6,$2,$4,$5,$3}}' {params.tmp5} > {output.ref_clu}

        #rm {params.tmp} {params.tmp1}

        """

rule cluster_refinement_done:
    input:
        ref_clu = config["rdir"] + "/cluster_refinement/refined_clusters.tsv",
        ref_annot = config["rdir"] + "/cluster_refinement/refined_annotated_clusters.tsv",
        ref_noannot = config["rdir"] + "/cluster_refinement/refined_not_annotated_clusters.tsv"
    output:
        ref_done = touch(config["rdir"] + "/cluster_refinement/ref.done")
    run:
        shell("echo 'CLUSTER REFINEMENT DONE'")
