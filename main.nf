#!/usr/bin/env nextflow
/* 
======================================================================================
			Expansion Hunter - Nextflow Trial
======================================================================================
*/

/*
======================================================================================
======================================================================================
======				   Parameters					======
======================================================================================
======================================================================================
*/

def helpMessage() {

	println """
	Usage:

	--help				To Show this Message
	
	Required arguments:
	--reads				BAM/CRAM file with aligned reads
	--reference			FASTA file with reference genome
	--variant_catalog			JSON file with variants to genotype
	--output_prefix			Prefix for the output files

	Optional arguments:
	--reads_index			Index to BAM/CRAM files. If not in same DIR
	--region_extension_length	How far from on/off-target regions to search
					for informative reads (Default = 1000)
	--sex				Sex of the sample; must be either male or 
					female (default)
	--log_level			trace, debug, info (default), warn or error
	--aligner			Specify which aligner to use
					(dag-aligner (default) or path-aligner)
	--analysis_mode			Specify which analysis workflow to use
					(seeking (default) or streaming) 
	""".stripIndent()
}

params.help = false

// Show help message
if (params.help) {
	helpMessage()
	exit 0
}

/*
===================================================================
===================================================================
			Default Parameter values
===================================================================
*/

params.reads = false
params.reads_index = false
params.reference = false
params.variant_catalog = false
params.output_prefix = false
params.region_extension_length = 1000
params.sex = "female"
params.log_level = "info"
params.aligner = "dag-aligner"
params.analysis_mode = "seeking"

/*
===================================================================
===================================================================
======			Validate Inputs			     ======
===================================================================
*/

if(params.reads){
	Channel.fromPath(params.reads, checkIfExists: true)
			.ifEmpty { exit 1, "BAM/CRAM file not found: ${params.reads}" }
			//.set { reads_file }

	reads_file = file(params.reads)
	// Get the index files if they exists.
	// Otherwise set flag to perform indexing using either salmon or bowtie2
	if(params.reads_index){
		Channel.fromPath(params.reads_index, checkIfExists: true)
				.ifEmpty {exit 2, "Index of BAM/CRAM file not found: ${params.reads_index}" }
		reads_index = file(params.reads_index)
	} else if (reads_file.getClass() == sun.nio.fs.UnixPath) {
		ext = (reads_file.getExtension() == "cram") ? ".crai" : ".bai"
		reads_index = "${reads_file.getParent()}/${reads_file.getBaseName()}.${reads_file.getExtension()}" + "${ext}"
		reads_index = file(reads_index)
	} else if (reads_file.getClass() == LinkedList) {
		reads_index = []
		for (def index : reads_file) {
			ext = (index.getExtension() == "cram") ? ".crai" : ".bai"
			reads_index.add(file("${index.getParent()}/${index.getBaseName()}.${index.getExtension()}" + "${ext}"))
		}
	} else {
	//Probably wont be triggered
		exit 2, "Index of BAM/CRAM file not specified/found!"
	}
} else {
	exit 1, "BAM/CRAM file not specified!"
}

if(params.reference){
	reference_file = Channel.fromPath(params.reference, checkIfExists: true)
					.ifEmpty { exit 1, "FASTA reference file not found: ${params.reference}" }

//	reference_file = file(params.reference)
} else {
	exit 1, "FASTA reference file not specificied!"
}

if(params.variant_catalog) {
	variant_file = Channel.fromPath(params.variant_catalog, checkIfExists: true)
					.ifEmpty {exit 1, "Variant Catalog file not found: ${params.variant_catalog}" }
	
	// variant_file = file(params.variant_catalog)
} else {
	exit 1, "Variant Catalog file not specificied!"
}

if(!params.output_prefix) {
	if(reads_file.getClass() == sun.nio.fs.UnixPath) {
		params.output = "$baseDir/${reads_file.getBaseName()}_results"
	} else {
		params.output = "$baseDir/Results"
	}
}


process index {

	input:
	file reads from reads_file
	file index from reads_index

	output:
	file reads into file_reads
	file "${index.getBaseName()}.${index.getExtension()}" into index_reads

	script:
	
	"""
	touch ${index.getBaseName()}.${index.getExtension()}
	"""

}

process trial {
	input:
	file reads from file_reads
	file index from index_reads
	file var from variant_file
	file ref from reference_file

	script:
	// Need to change the path for ExpansionHunter. 
	"""
	$HOME/summer-p/methods/ExpansionHunter/bin/ExpansionHunter --reads $reads --reference $ref --variant-catalog $var --output-prefix ${params.output_prefix}
	"""
}


