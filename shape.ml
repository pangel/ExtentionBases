module Make (Node:Node.NodeType) =
  struct
    module Cat = Cat.Make (Node)
    module Graph = Graph.Make (Node)
    module Hom = Homomorphism.Make (Node)

    module Model = Model.Make (Node)
    module EB = Basis.Make (Node)

    open Lib.Util

    let draw_line u v g =
      let g =
	List.fold_left
	  (fun g u ->
	   Graph.add_node u g
	  ) g [u;v] in
      Graph.add_edge u v g

    let rec draw line_list g =
      match line_list with
	[] -> g
      | (u,v)::tl ->
	 let g' = draw_line u v g in
	 draw tl g'


    let graph_of_library name =
      try
	let edges = Lib.StringMap.find name Node.library in
	draw edges Graph.empty
      with
	Graph.Incoherent -> failwith (name^" is not a coherent graph!")

    let (=>) = Cat.(=>)
    let (|>) = Cat.(|>)
    let (<|) = fun x y -> (y |> x)

    let simple_tests debug =
      if debug then debug_mode () ;
      let one = graph_of_library "one" in
      let house = graph_of_library "house" in
      let dsquare = graph_of_library "dsquare" in
      let square = graph_of_library "square" in
      let f_list = Cat.flatten (Cat.extension_class (one => house)) in
      let g_list = Cat.flatten (Cat.extension_class (one => house)) in
      List.iter
        (fun f ->
         List.iter (fun g ->
                    let sharing = Cat.share f g in
                    begin
                      match sharing with
                        Some (_,tile) -> print_string (Cat.string_of_tile tile)
                      | None -> print_string "None"
                    end ;
                    print_newline() 
                   ) g_list
        ) f_list ;
      print_newline();
      print_string "square |> one one\n" ;
      List.iter (fun tile ->
		 let emb = Cat.arrows_of_tile tile in
		 Printf.printf "%s:\n %s\n" (Cat.string_of_arrows emb) (Cat.string_of_tile tile)
		) (square |> (Graph.sum one one))

    let generate_tests debug =
      if debug then debug_mode () ;

      if db() then Printexc.record_backtrace true ;
      let one = graph_of_library "one" in
      let house = graph_of_library "house" in
      let model = Lib.StringMap.fold
		    (fun name _ model ->
		     if (*(name = "one") || (name = "triangle") ||*) (name = "square") (*|| (name = "dsquare")*) || (name = "house") then
                       Model.add_obs name (graph_of_library name) model
                     else model
		    ) Node.library Model.empty
      in
      let nw,pw = Model.witnesses_of_rule (Graph.empty,one) model in
      let get_seed = function
          (id_obs,tile)::_ -> Cat.left_of_tile tile
        | [] -> Graph.empty
      in
      let neg_ext_base =
        List.fold_left
          (fun ext_base (id_obs,tile) ->
           match Cat.upper_bound tile with
             None -> failwith "no witness"
           | Some (to_w,from_o) ->
              if db() then
                Printf.printf "Inserting witness of observable \"%s\": %s\n"
			      (Lib.Dict.to_name id_obs model.Model.dict)
			      (Cat.string_of_cospan (to_w,from_o)) ;
              EB.insert to_w from_o id_obs ext_base
          ) (EB.empty (get_seed nw)) nw
      in
      let pos_ext_base =
        List.fold_left
          (fun ext_base (id_obs,tile) ->
           match Cat.upper_bound tile with
             None -> failwith "no witness"
           | Some (to_w,from_o) ->
              if db() then
                Printf.printf "Inserting witness of observable '%s': %s\n"
			      (Lib.Dict.to_name id_obs model.Model.dict)
			      (Cat.string_of_cospan (to_w,from_o)) ;
              EB.insert to_w from_o id_obs ext_base
          ) (EB.empty (get_seed pw)) pw
      in
      let d = open_out "neg_base.dot" in
      let d' = open_out "pos_base.dot" in
      Printf.fprintf d "%s\n" (EB.to_dot model.Model.dict neg_ext_base) ;
      Printf.fprintf d' "%s\n" (EB.to_dot model.Model.dict pos_ext_base) ;
      close_out d ;
      close_out d'

  end

module SimpleShape = Make (Node.SimpleNode)
module KappaShape = Make (Node.KappaNode)
module DegreeShape = Make (Node.DegreeNode)
