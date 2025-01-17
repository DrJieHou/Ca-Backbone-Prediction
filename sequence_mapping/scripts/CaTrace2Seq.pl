#!/usr/bin/perl -w

our %AA3TO1 = qw(ALA A ASN N CYS C GLN Q HIS H LEU L MET M PRO P THR T TYR Y ARG R ASP D GLU E GLY G ILE I LYS K PHE F SER S TRP W VAL V);
our %AA1TO3 = reverse %AA3TO1;

$installation_dir = '/home/jh7x3/CaTrace2Seq/';
if (@ARGV !=5)
{
	die "Error: need five parameters: <path of Ca trace> <path of fasta sequence> <output-directory> <length threshold for fragment> <number of cpus>\n";
}
#### (1) Initialize the parameters
$input_pdb = shift @ARGV;
$fasta_file = shift @ARGV;
$outputfolder = shift @ARGV;
$len_threshold = shift @ARGV;
$proc_num = shift @ARGV;


#### (2) Checking the input files and output directory
-d $outputfolder || `mkdir $outputfolder`;
#get query name and sequence 
open(FASTA, $fasta_file) || die "Error: can't read fasta file $fasta_file.\n";
@content = <FASTA>;
$target_id = shift @content;
chomp $target_id;
$qseq = shift @content;
chomp $qseq;
close FASTA;


#rewrite fasta file if it contains lower-case letter
if ($qseq =~ /[a-z]/)
{
	print "There are lower case letters in the input file. Convert them to upper case.\n";
	$qseq = uc($qseq);
	open(FASTA, ">$outputfolder/$target_id.fasta") || die "Error: can't rewrite fasta file.\n";
	print FASTA "$target_id\n$qseq\n";
	close FASTA;
}


if ($target_id =~ /^>/)
{
	$target_id = substr($target_id, 1); 
}
else
{
	die "Error: fasta foramt error.\n";
}


#####  (3) Get possible fragments in input pdb

open INPUTPDB, $input_pdb or die "ERROR! Could not open $input_pdb";
@lines_PDB = <INPUTPDB>;
close INPUTPDB;

-d "$outputfolder/frag_dir" || `mkdir $outputfolder/frag_dir`;

#@PDB_temp=();
$frag_num=0;
$frag_start = 0;
%frag_CAs = ();
$CA_num = 0;
foreach (@lines_PDB) {
  $line = $_;
  chomp $line;
 
  if(substr($line,0,3) eq 'TER')
  {
    $frag_start = 0;
    next;  
  }
  
  next if $line !~ m/^ATOM/;
  #@tmp = split(/\s+/,$line);
  $atomtype = parse_pdb_row($line,"aname");
  next if $atomtype ne 'CA'; 
  
  
  if($frag_start == 0)
  {
    $frag_num++;
    $frag_start = 1;
    if($frag_num>1)
    {
      $idx = $frag_num-1;
      $frag_CAs{$idx} = $CA_num;
      print "Fragement $idx has $CA_num atoms\n";
      close TMP;
    }
    $fragfile = "$outputfolder/frag_dir/frag$frag_num.pdb";
    open(TMP,">$fragfile") || die "Failed to open file $fragfile\n\n";
    print TMP "$line\n";
    $CA_num = 1;
    next;  
  }
  
  print TMP "$line\n";
  $CA_num ++;
  
}
close TMP;


print "Total $frag_num fragments are found\n";



if($frag_num == 1)
{ 
  $init_pdb = "$outputfolder/frag_dir/frag1.pdb";
  
   
  open INPUTPDB, "$outputfolder/frag_dir/frag1.pdb" or die "ERROR! Could not open $outputfolder/frag_dir/frag1.pdb\n";
  
  @lines_PDB = <INPUTPDB>; 
  close INPUTPDB;
  $pdb_seq="";
  $pdb_record = ();
  foreach (@lines_PDB) {
  	next if $_ !~ m/^ATOM/;
  	next unless (parse_pdb_row($_,"aname") eq "CA");
  	$this_rchain = parse_pdb_row($_,"chain");
  	$rname = $AA3TO1{parse_pdb_row($_,"rname")};
  	$rnum = parse_pdb_row($_,"rnum");
    if(exists($pdb_record{"$this_rchain-$rname-$rnum"}))
    {
      next;
    }else{
      $pdb_record{"$this_rchain-$rname-$rnum"} = 1;
    }
    
    $pdb_seq .= $rname;
  }
  if(length($pdb_seq) < $len_threshold)
  {
  	goto FINISH;
  }
  
  
  if(length($pdb_seq) > length($qseq))
  {
    print "perl $installation_dir/scripts/generate_alignment_case1.pl  $init_pdb $fasta_file  $outputfolder/frag1_fitting $proc_num\n\n";
    `perl $installation_dir/scripts/generate_alignment_case1.pl  $outputfolder/frag_dir/frag1.pdb $fasta_file  $outputfolder/frag1_fitting $proc_num`;
  }else{
    print "perl $installation_dir/scripts/generate_alignment_case2.pl  $init_pdb $fasta_file  $outputfolder/frag1_fitting $proc_num\n\n";
    `perl $installation_dir/scripts/generate_alignment_case2.pl  $outputfolder/frag_dir/frag1.pdb $fasta_file  $outputfolder/frag1_fitting $proc_num`;
  }
  

	## score by modeleva/qprob

	`mkdir -p $outputfolder/frag1_fitting/qprob/Models`;

	`cp -ar $outputfolder/frag1_fitting/Models/*pdb $outputfolder/frag1_fitting/qprob/Models`;
	print("sh $installation_dir/tools/qprob_package/bin/Qprob.sh $fasta_file  $outputfolder/frag1_fitting/qprob/Models $outputfolder/frag1_fitting/qprob/\n\n");
	`sh $installation_dir/tools/qprob_package/bin/Qprob.sh $fasta_file  $outputfolder/frag1_fitting/qprob/Models $outputfolder/frag1_fitting/qprob/`;

	@tem111 = split(/\//,$fasta_file );
	@tem111 = split(/\./,$tem111[@tem111-1]);
	$name = $tem111[0];


	$scorefile = "$outputfolder/frag1_fitting/qprob//$name.Qprob_score";
	if(!(-e $scorefile))
	{
		print "Failed to find $scorefile\n";
		goto FINISH;
	}
	open(TMPFILE,"$scorefile") || die "Failed to open file $scorefile\n";
	@content_tmp = <TMPFILE>;
	close TMPFILE;
	$info = shift @content_tmp;
	@content_tmp2 = split(/\s+/,$info);
	$best_model = $content_tmp2[0]; #temp_r_NC_78.pdb

	`cp $outputfolder/frag1_fitting/qprob/Models/$best_model $outputfolder/frag1_fitting.pdb`;
  
	@content_tmp3 = split('_',substr($best_model,0,index($best_model,'.pdb')));
	$start_pos = $content_tmp3[@content_tmp3-1]+1;
	$end_pos =  $start_pos +  $frag_len -1;


	#
	`perl $installation_dir/scripts/extract_atom.pl $outputfolder/frag1_fitting.pdb $outputfolder/frag1_fitting_${start_pos}_${end_pos}.pdb $start_pos $end_pos`;


  
}else{

  ### sort fragments by length
  $idx=0;
  foreach $fragidx (sort { $frag_CAs{$b} <=> $frag_CAs{$a} } keys %frag_CAs) 
  {
    $frag_len = $frag_CAs{$fragidx};
    if($frag_len<10)
    {
      next;
    }
    $frag1 = "$outputfolder/frag_dir/frag$fragidx.pdb";

    ##### (3) add pulchar and side-chain
    
    open(TMP1, "$frag1") || die "Failed to open $frag1\n";
    @content1 = <TMP1>;
    close TMP1;
    $Ca_index = 0;
    $atom_index=0;  
    $this_rchain="";
    $pdb_seq="";  
    -d "$outputfolder/frag_dir_sorted" || `mkdir $outputfolder/frag_dir_sorted`;
    $idx++;
    $frag1_sort = "$outputfolder/frag_dir_sorted/frag${idx}.pdb";
    open(OUTPDB,">$frag1_sort") || die "Failed to open $frag1_sort\n";
    foreach(@content1)
    {
      	$line = $_;
      	chomp $line;
      	next if $line !~ m/^ATOM/;
      	#$atomCounter = parse_pdb_row($line,"anum");
      	$atomtype = parse_pdb_row($line,"aname");
      	$resname = parse_pdb_row($line,"rname");
      	$chainid = parse_pdb_row($line,"chain");
      	#$resCounter = parse_pdb_row($line,"rnum");
        $this_rchain = $chainid;
        
        if($atomtype eq 'CA')
        {
          $Ca_index++;
          $pdb_seq .= $AA3TO1{$resname};
        }
        $atom_index++;
         
        $x = parse_pdb_row($line,"x");
        $y = parse_pdb_row($line,"y");
        $z = parse_pdb_row($line,"z");
       
      	
        
      	$rnum_string = sprintf("%4s", $Ca_index);
      	$anum_string = sprintf("%5s", $atom_index);
      	$atomtype = sprintf("%4s", $atomtype);
      	$x = sprintf("%8s", $x);
      	$y = sprintf("%8s", $y);
      	$z = sprintf("%8s", $z);
      	$row = "ATOM  ".$anum_string.$atomtype."  ".$resname." ".$chainid.$rnum_string."    ".$x.$y.$z."\n";
      	print OUTPDB $row;
    }
    close OUTPDB;
  

    if($idx == 1)
    {
      ### first map the largest fragment
      if(length($pdb_seq) > length($qseq))
      {
        print "perl $installation_dir/scripts/generate_alignment_case1.pl  $frag1_sort $fasta_file  $outputfolder/frag${idx}_fitting $proc_num\n\n";
        system("perl $installation_dir/scripts/generate_alignment_case1.pl  $frag1_sort $fasta_file  $outputfolder/frag${idx}_fitting $proc_num");
      }else{
        print "perl $installation_dir/scripts/generate_alignment_case2.pl  $frag1_sort $fasta_file  $outputfolder/frag${idx}_fitting $proc_num\n\n";
        system("perl $installation_dir/scripts/generate_alignment_case2.pl  $frag1_sort $fasta_file  $outputfolder/frag${idx}_fitting $proc_num");
      }
      
      ## score by modeleva/qprob
      
		`mkdir -p $outputfolder/frag${idx}_fitting/qprob/Models`;

		`cp -ar $outputfolder/frag${idx}_fitting/Models/*pdb $outputfolder/frag${idx}_fitting/qprob/Models`;
		print("sh $installation_dir/tools/qprob_package/bin/Qprob.sh $fasta_file  $outputfolder/frag${idx}_fitting/qprob/Models $outputfolder/frag${idx}_fitting/qprob/\n\n");
		system("sh $installation_dir/tools/qprob_package/bin/Qprob.sh $fasta_file  $outputfolder/frag${idx}_fitting/qprob/Models $outputfolder/frag${idx}_fitting/qprob/");

		@tem111 = split(/\//,$fasta_file );
		@tem111 = split(/\./,$tem111[@tem111-1]);
		$name = $tem111[0];


		$scorefile = "$outputfolder/frag${idx}_fitting/qprob//$name.Qprob_score";
		if(!(-e $scorefile))
		{
			print "Failed to find $scorefile\n";
			goto FINISH;
		}
		open(TMPFILE,"$scorefile") || die "Failed to open file $scorefile\n";
		@content_tmp = <TMPFILE>;
		close TMPFILE;
		$info = shift @content_tmp;
		@content_tmp2 = split(/\s+/,$info);
		$best_model = $content_tmp2[0]; #temp_r_NC_78.pdb
		
		`cp $outputfolder/frag${idx}_fitting/qprob/Models/$best_model $outputfolder/frag${idx}_fitting.pdb`;
          
        @content_tmp3 = split('_',substr($best_model,0,index($best_model,'.pdb')));
        $start_pos = $content_tmp3[@content_tmp3-1]+1;
        $end_pos =  $start_pos +  $frag_len -1;
        
        
        #
        `perl $installation_dir/scripts/extract_atom.pl $outputfolder/frag${idx}_fitting.pdb $outputfolder/frag${idx}_fitting_${start_pos}_${end_pos}.pdb $start_pos $end_pos`;

		$frag_info = "$outputfolder/frag${idx}_fitting.pdb $start_pos $end_pos";
		`echo "$frag_info" > $outputfolder/fitted_fragements.info`;
		
		
        
     
     


    }else{
        ### mapping remaining fragments
        print "perl $installation_dir/scripts/generate_alignment_case2_update.pl  $frag1_sort $fasta_file $outputfolder/frag${idx}_fitting 10  $proc_num $outputfolder/fitted_fragements.info\n\n";
        system("perl $installation_dir/scripts/generate_alignment_case2_update.pl  $frag1_sort $fasta_file $outputfolder/frag${idx}_fitting 10  $proc_num $outputfolder/fitted_fragements.info");
     
     
         ## score by modeleva/qprob
      
		`mkdir -p $outputfolder/frag${idx}_fitting/qprob/Models`;

		`cp -ar $outputfolder/frag${idx}_fitting/Models/*pdb $outputfolder/frag${idx}_fitting/qprob/Models`;
		 print("sh $installation_dir/tools/qprob_package/bin/Qprob.sh $fasta_file  $outputfolder/frag${idx}_fitting/qprob/Models $outputfolder/frag${idx}_fitting/qprob/\n\n");
		`sh $installation_dir/tools/qprob_package/bin/Qprob.sh $fasta_file  $outputfolder/frag${idx}_fitting/qprob/Models $outputfolder/frag${idx}_fitting/qprob/`;

		@tem111 = split(/\//,$fasta_file );
		@tem111 = split(/\./,$tem111[@tem111-1]);
		$name = $tem111[0];


		$scorefile = "$outputfolder/frag${idx}_fitting/qprob//$name.Qprob_score";
		if(!(-e $scorefile))
		{
			print "Failed to find $scorefile\n";
			goto FINISH;
		}
		open(TMPFILE,"$scorefile") || die "Failed to open file $scorefile\n";
		@content_tmp = <TMPFILE>;
		close TMPFILE;
		$info = shift @content_tmp;
		@content_tmp2 = split(/\s+/,$info);
		$best_model = $content_tmp2[0]; #temp_r_NC_78.pdb
		
		`cp $outputfolder/frag${idx}_fitting/qprob/Models/$best_model $outputfolder/frag${idx}_fitting.pdb`;
          
        @content_tmp3 = split('_',substr($best_model,0,index($best_model,'.pdb')));
        $start_pos = $content_tmp3[@content_tmp3-1]+1;
        $end_pos =  $start_pos +  $frag_len -1;
        
        
        #
        `perl $installation_dir/scripts/extract_atom.pl $outputfolder/frag${idx}_fitting.pdb $outputfolder/frag${idx}_fitting_${start_pos}_${end_pos}.pdb $start_pos $end_pos`;

		$frag_info = "$outputfolder/frag${idx}_fitting.pdb $start_pos $end_pos";
		`echo "$frag_info" >> $outputfolder/fitted_fragements.info`;
		
		
    }
    
    
  }
}
################## Sequence mapping is done!

FINISH:
print "Sequence mapping is done!\n";

sub generate_gaps
{
	$gnum = $_[0]; 	
	$gaps = "";
	for ($i = 0; $i < $gnum; $i++)
	{
		$gaps .= "-"; 
	}
	return $gaps; 
}

sub generate_aa
{
	$gnum = $_[0]; 	
	$gaps = "";
	for ($i = 0; $i < $gnum; $i++)
	{
		$gaps .= "G"; 
	}
	return $gaps; 
}


sub parse_pdb_row{
	$row = shift;
	$param = shift;
	$result = substr($row,6,5) if ($param eq "anum");
	$result = substr($row,12,4) if ($param eq "aname");
	$result = substr($row,16,1) if ($param eq "altloc");
	$result = substr($row,17,3) if ($param eq "rname");
	$result = substr($row,22,5) if ($param eq "rnum");
	$result = substr($row,21,1) if ($param eq "chain");
	$result = substr($row,30,8) if ($param eq "x");
	$result = substr($row,38,8) if ($param eq "y");
	$result = substr($row,46,8) if ($param eq "z");
	die "Invalid row[$row] or parameter[$param]" if (not defined $result);
	$result =~ s/\s+//g;
	return $result;
}
