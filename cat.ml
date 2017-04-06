
module Make (Node:Node.NodeType) =
  struct
    module Hom = Homomorphism.Make (Node)
    module Graph = Graph.Make (Node)

    module NodeSet = Set.Make (Node)

    exception Undefined		
    type embeddings = {src : Graph.t ; trg : Graph.t ; maps : Hom.t list}

    let is_span emb1 emb2 =
      Graph.is_equal emb1.src emb2.src
		     
    let is_co_span emb1 emb2 =
      Graph.is_equal emb1.trg emb2.trg
		     
    let string_of_embeddings emb = 
      String.concat "," (List.map Hom.to_string emb.maps)

    let string_of_span (emb,emb') =
      assert (is_span emb emb') ;
      let str = Printf.sprintf "SRC = %s \n" (Graph.to_string emb.src) in
      str^(string_of_embeddings emb)^"\n"^(string_of_embeddings emb')

    let string_of_co_span (emb,emb') =
      assert (is_co_span emb emb') ;
      let str = Printf.sprintf "\nTRG = %s" (Graph.to_string emb.trg) in
      (string_of_embeddings emb)^"\n"^(string_of_embeddings emb')^str

					    
    let (=>) g h =
      let rec extend hom_list iG jG acc =
	match hom_list with
	  [] -> acc
	| phi::tl ->
	   try
	     let iH = Hom.find iG phi in
	     let opt = try Some (Hom.find jG phi) with Not_found -> None in
	     match opt with
	       None ->
	       let biH = Graph.bound_to iH h in
	       let ext =
		 List.fold_left
		   (fun cont jH ->
		    try
		      let phi_ext = Hom.add jG jH phi in
		      phi_ext::cont
		    with
		      Hom.Not_injective | Hom.Not_structure_preserving -> cont
		   ) [] biH
	       in
	       extend tl iG jG (ext@acc)
	     | Some jH ->
		if Graph.has_edge iH jH h then extend tl iG jG (phi::acc)
		else extend tl iG jG acc
	   with Not_found -> failwith "Invariant violation" 
      in
      let rec explore_cc i hom_list already_done =
	List.fold_left
	  (fun (hom_list,already_done) j ->
	   let hom_list' = extend hom_list i j [] in
	   if NodeSet.mem j already_done then
	     (hom_list',already_done)
	   else
	     explore_cc j hom_list' (NodeSet.add j already_done)
	  ) (hom_list,already_done) (Graph.bound_to i g) 
      in
      let extend_next_root u hom_list g h =
	List.fold_left (fun hom_list hom ->
			let fold_candidates_u =
			  match Hom.id_image u hom with
			    None -> (*if [Node.id u] is not yet constrained by [hom]*)
			    (fun f -> Graph.fold_nodes f h) 
			  | Some i -> (*Looking for a candidate among those having [hom (Node.id u)] as id*)
			     (fun f -> List.fold_right f (Graph.nodes_of_id i h)) 
			in
			let hom_extended_with_candidates_u =
			  fold_candidates_u 
			    (fun u' cont ->
			     if (Graph.degree u g) <= (Graph.degree u' h) then
			       try
				 (Hom.add u u' hom)::cont
			       with
				 Hom.Not_structure_preserving | Hom.Not_injective -> cont
			     else
			       cont
				 
			    ) []
			in
			hom_extended_with_candidates_u@hom_list
		       ) [] hom_list
      in
      let cc_roots = Graph.connected_components g in
      List.fold_left
	(fun hom_list u ->
	 let hom_list_u = extend_next_root u hom_list g h in
	 let hom_list_extended,_ = explore_cc u hom_list_u (NodeSet.singleton u) in
	 hom_list_extended
	) [Hom.empty] cc_roots

    let embed g h = 
      match g=>h with
	[] -> raise Undefined
       | maps -> {src = g ; trg = h ; maps = maps}


    let horizontal_compose emb emb' = 
      let maps =
	List.fold_left
	  (fun maps hom ->
	   let hom_added =
	     List.fold_left
	       (fun hom_added hom' ->
		try
		  (Hom.sum hom hom')::hom_added
		with
		  Hom.Not_structure_preserving | Hom.Not_injective -> hom_added
	       ) [] emb'.maps
	   in
	   hom_added@maps
	  ) [] emb.maps
      in
      if maps = [] then raise Undefined
      else
	let src = Graph.join emb.src emb'.src in
	let trg = Graph.join emb.trg emb'.trg in
	{src = src ; trg = trg ; maps = maps}	

    let vertical_compose emb emb' =
      let maps =
	List.fold_left
	  (fun maps hom ->
	   let hom_ext_list = 
	     List.fold_left 
	       (fun maps hom' ->
		try
		  (Hom.compose hom hom')::maps
		with
		  Hom.Not_injective -> maps
	       ) maps emb'.maps
	   in
	   hom_ext_list@maps
	  ) [] emb.maps
      in
      if maps = [] then raise Undefined
      else
	{src = emb.src ; 
	 trg = emb'.trg ; 
	 maps = maps}
      	 

    let eq_class matching emb auto =
      let close_span hom hom' =
	try
	  Hom.fold (fun u v phi ->
		    assert (Hom.mem u hom') ; 
		    let v' = Hom.find u hom' in
		    Hom.add v v' phi
		   ) hom Hom.empty
	with
	  Hom.Not_structure_preserving | Hom.Not_injective -> failwith "Invariant violation"
      in
      let close_co_span hom hom' =
	try
	  Hom.fold (fun u v phi ->
		    assert (Hom.comem v hom') ; 
		    let u' = Hom.cofind v hom' in
		    Hom.add u u' phi
		   ) hom Hom.empty
	with
	  Hom.Not_structure_preserving | Hom.Not_injective -> failwith "Invariant violation"
      in
      let reduced_maps = 
	List.fold_left
	  (fun quotient hom ->
	   if List.exists (fun hom' ->
			   (Hom.is_equal hom hom') ||
			     let phi =
			       if matching then close_co_span hom hom'
			       else close_span hom hom'
			     in
			     List.exists (fun psi -> Hom.is_sub phi psi) auto
			  ) quotient
	   then quotient
	   else hom::quotient
	  ) []
	  (List.fast_sort (*keeping identity morphisms if possible*)
	     (fun hom hom' ->
	      if Hom.is_identity hom then -1 else
		if Hom.is_identity hom' then 1
		else 0
	     ) emb.maps
	  )
      in
      assert (reduced_maps <> []) ;
      {emb with maps = reduced_maps}
	  
    let extension_class emb =
      let auto = (emb.trg => emb.trg) in
      eq_class false emb auto
	       
    let matching_class emb =
      let auto = (emb.src => emb.src) in
      eq_class true emb auto

	  
    let multi_pushout maps g1 g2 = (*maps: infG1G2 -> G2*)
      
      let extend_partial hom graph fresh =
	
	let apply_ext_hom u hom fresh =
	  match Hom.id_image u hom with
	    None ->
	    let u' = Node.rename fresh u in
	    (u', Hom.add u u' hom, fresh+1)
	  | Some i -> 
	     try (Hom.find u hom,hom,fresh)
	     with Not_found ->
	       let u' = Node.rename i u in
	       (u',Hom.add u u' hom,fresh)
	in
	let graph',hom',_ = 
	  Graph.fold_edges
	    (fun u v (graph',hom,fresh) ->
	     let u',hom',fresh' = apply_ext_hom u hom fresh
	     in
	     let v',hom'',fresh'' = apply_ext_hom v hom' fresh'
	     in
	     let graph' = Graph.add_node u' (Graph.add_node v' graph') in
	     let graph' =
	       try
		 Graph.add_edge u' v' graph'
	       with
		 Graph.Incoherent ->
		 (
		   Printf.printf "Cannot add (%s,%s)\n" (Node.to_string u') (Node.to_string v') ;
		   failwith "Invariant violation"
		 )
	     in
	     (graph',hom'',fresh'')
	    ) graph (Graph.empty,hom,fresh)
	in
	(hom',graph')
      in
      let fresh = (max (Graph.max_id g1) (Graph.max_id g2))+1
      in
      List.map
	(fun hom ->
	 let hom',g1' = extend_partial hom g1 fresh in
	 try
	   let gh_sup = Graph.join g2 g1'
	   in
	   (Some gh_sup,hom')
	 with
	   Graph.Incoherent -> (None,hom')
	 | Hom.Not_injective | Hom.Not_structure_preserving ->
				failwith "Invariant violation: cannot build homomorphism"
	) maps
	
    	
    let gluings g h =
      let rec enumerate_gluings one_gluings partial_gluings complete_gluings already_done =
	match partial_gluings with
	  [] -> complete_gluings
	| (n_gluing)::tl ->
	   let succ_n_gluings,complete_gluings',already_done' = 
	     List.fold_left
	       (fun (succ_n_gluings,complete_gluings,already_done) (one_gluing) ->
		try
		  if Graph.is_included one_gluing.src n_gluing.src then (succ_n_gluings,complete_gluings,already_done)
		  else
		    match try Some (horizontal_compose one_gluing n_gluing) with Undefined -> None
		    with
		      None -> (succ_n_gluings,complete_gluings,already_done)
		    | Some succ_n_hset ->
		       (*On verifie ici que succ_n_hset n'est pas deja dans succ_n_gluings*)
		       if List.exists
			    (fun g ->
			     Graph.is_equal g succ_n_hset.src
			    ) already_done
		       then (succ_n_gluings,complete_gluings,already_done)
		       else
			 let complete_gluings' = succ_n_hset::complete_gluings in
			 (succ_n_hset::succ_n_gluings,complete_gluings',succ_n_hset.src::already_done)
		with
		  Hom.Not_structure_preserving -> failwith "Invariant violation: not structure preserving"
		| Hom.Not_injective -> (succ_n_gluings,complete_gluings,already_done)
	       ) ([],complete_gluings,already_done) one_gluings
	   in
	   enumerate_gluings one_gluings (tl@succ_n_gluings) complete_gluings' already_done'
      in
      let subgraphs_of_edges graph =
	try
	  Graph.fold_edges
	    (fun u v subgraphs ->
	     let subg = Graph.add_node u (Graph.add_node v Graph.empty) in
	     (Graph.add_edge u v subg)::subgraphs
	    ) graph []
	with
	  Graph.Incoherent -> failwith "Invariant violation: graph is incoherent"
      in
      let one_gluings = 
	List.fold_left
	  (fun arr_list subh ->
	   try 
	     let embeddings = embed subh g 
	     in
	     embeddings::arr_list
	   with
	     Undefined -> arr_list
	  ) [] (subgraphs_of_edges h)
      in
      let gluing_points = 
	List.map extension_class (enumerate_gluings one_gluings one_gluings one_gluings [])
      in
      List.fold_left (fun cont embeddings -> 
		      let is_max infGH =
			try
			  (List.fold_left
			     (fun _ emb ->
			      if (Graph.size_edge infGH < Graph.size_edge emb.src)
				 && (Graph.is_included infGH emb.src)
			      then raise Pervasives.Exit
			     ) () gluing_points ; true)
			with
			  Pervasives.Exit -> false
		      in
		      let mpo = multi_pushout embeddings.maps h g in 
		      let infGH = embeddings.src in
		      let gluings =
			List.fold_left
			  (fun tiles (supGH_opt,hom) ->
			   let infGH_to_H = Hom.identity (Graph.nodes infGH) in
			   let infGH_to_G =
			     Graph.fold_nodes
			       (fun u hom' ->
				try
				  Hom.add u (Hom.find u hom) hom'
				with
				  Not_found -> hom'
				| _ -> failwith "Invariant violation"
			       ) infGH Hom.empty
			   in
			   let span =
			     ({src = infGH ; trg = h ; maps = [infGH_to_H]},
			      {src = infGH ; trg = g ; maps = [infGH_to_G]})
			   in
		  	   match supGH_opt with
			     None -> if is_max infGH then
				       (span,None)::tiles
				     else tiles
			   | Some supGH ->
			      let co_span =
				({src = h ; trg = supGH ; maps = [hom]},
				 {src = g ; trg = supGH ; maps = [Hom.identity (Graph.nodes g)]})
			      in
			      (span,Some co_span)::tiles
			  ) [] mpo
		      in
		      gluings@cont
		     ) [] gluing_points

    let add_sharing (emb,emb') min_opt =
      assert (is_span emb emb') ;
      let size_src = Graph.size_edge emb.src in
      List.fold_left
	(fun sharings ((emb0,emb1),cospan_opt) ->
	 let size_src' = Graph.size_edge emb0.src in
	 if
	   match min_opt with
	     None -> true
	   | Some n ->  (size_src' - size_src) >= n
	 then
	   ({src = emb.src ; trg = emb0.src ; maps = [Hom.identity (Graph.nodes emb.src)]},(emb0,emb1),cospan_opt)::sharings
	 else sharings
	) [] (gluings emb.trg emb'.trg)
           
		     
  end
