module Make (Node:Node.NodeType) =
  struct
    module NodeBij = Bijection.Make (Node)
    module IntBij =
      Bijection.Make (struct type t = int let compare = compare let to_string = string_of_int end)

    exception Not_structure_preserving
    exception Not_injective

    type t = {tot : NodeBij.t ; sub : IntBij.t }

    let size hom = NodeBij.size hom.tot

    let is_equal hom hom' = NodeBij.is_equal (fun u v -> Node.compare u v = 0) hom.tot hom'.tot

    let is_sub hom hom' =
      try
	NodeBij.fold
	  (fun u v b ->
	   let v' = NodeBij.find u hom'.tot in
	   (compare v v' = 0) && b
	  ) hom.tot true
      with
	Not_found -> false

    let empty =
      {tot = NodeBij.empty ;
       sub = IntBij.empty
      }

    let invert hom =
      {tot = NodeBij.invert hom.tot ;
       sub = IntBij.invert hom.sub}

    let identity nodes =
      {tot = NodeBij.identity nodes ;
       sub = IntBij.identity (List.map Node.id nodes)
      }

    let is_empty hom = NodeBij.is_empty hom.tot

    let is_identity hom = NodeBij.is_identity hom.tot

    let add_sub u_i v_i hom =
      let bij = IntBij.add u_i v_i hom.sub in
      {hom with sub = bij}

    let add u v hom =
      if (Node.compatible u v) then () else raise Not_structure_preserving ;
      let u_i,v_i = Node.id u,Node.id v in
      try
	let hom' = add_sub u_i v_i hom
	in
	assert (
	    match (try Some (NodeBij.find u hom.tot) with Not_found -> None) with
	      None -> true
	    | Some v' -> (Node.compare v v') = 0
	  ) ;
	{hom' with tot = NodeBij.add u v hom.tot}
      with
	NodeBij.Not_bijective _ | IntBij.Not_bijective _ -> raise Not_injective

    let find u hom = NodeBij.find u hom.tot
    let cofind u hom = NodeBij.cofind u hom.tot
    let find_sub i hom = IntBij.find i hom.sub
    let cofind_sub i hom = IntBij.cofind i hom.sub

    let add2 (u,v) (u',v') hom = add u u' (add v v' hom)
    let find2 (u,v) hom = (find u hom, find v hom)

    let find2_sub (u,v) hom = (find_sub u hom, find_sub v hom)
    let cofind2 (u,v) hom = (cofind u hom, cofind v hom)
    let cofind2_sub (u,v) hom = (cofind_sub u hom, cofind_sub v hom)


    let (-->) l1 l2 =
      let n1 = List.length l1 in
      let n2 = List.length l2 in
      if n2 < n1 then raise Not_injective
      else
        let hom,_ =
          List.fold_left (fun (hom,i) u -> (add u (List.nth l2 i) hom,i+1)) (empty,0) l1
        in
        hom

    let id_image u hom =
      try Some (IntBij.find (Node.id u) hom.sub) with Not_found -> None

    let fold f hom = NodeBij.fold (fun u v cont -> f u v cont) hom.tot

    let to_string ?(full=false) ?(sub=false) hom =
      if full then
        NodeBij.to_string hom.tot
      else
      IntBij.to_string hom.sub

    (*[compose h h'] = (h o h') *)
    let compose hom hom' =
      try
	fold (fun u v hom'' -> add u (find v hom) hom'') hom' empty
      with
	Not_found -> raise Not_injective

    let sum hom hom' = fold (fun u v hom_sum -> add u v hom_sum) hom hom'

    let mem u hom = NodeBij.mem u hom.tot
    let mem_sub i hom = IntBij.mem i hom.sub

    let comem u hom = NodeBij.comem u hom.tot
    let comem_sub i hom = IntBij.comem i hom.sub

    let to_dot_label hom =
      IntBij.to_dot_label hom.sub

  end

