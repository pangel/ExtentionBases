//
// Conversion graphlib -> cytoscape
//

// Turns an array to cytoscape nodes.
// If array elements are non-array, they represent the id and the label.
// Otherwise, every element is interpreted as [id,label]
let _nodes = ar => _.map(ar, e => {
  if (Array.isArray(e)) {
    return {data: {id: e[0], label: e[1]}};
  } else {
    return {data: {id: e, label: e}};
  }
});

// Splat version
let nodes = (...rest) => {
  return _nodes(rest);
}

// Turn id pair into edge
let edge = (i,j,info) => ({data: _.extend({id:`${i}-${j}`, source: i, target: j},info||{})});

//let edge_label = (i,j) => ({data: _.extend({sourceLabel: i, targetLabel: j},edge(i,j).data)});

// Splat-transform [[i,j]*] into [edgy(i,j)*]
let edges_generic = (edgy, ...ar) => {
  return _.union(_.map(ar, ([i,j,info]) => edgy(i,j,info)));
}

let edges = (...ar) => edges_generic(edge, ...ar);
let edges_label = (...ar) => edges_generic(edge_label, ...ar);

// Testing
let square = _.union(nodes(... _.range(1,5)),edges([1,2],[2,3],[3,4],[4,1]));
let house = _.union(square,nodes([5]),edges([2,5],[5,3]));
let triangle = _.union(nodes(... _.range(1,4)),edges([1,2],[2,3],[3,1]));
let brokensquare = _.union(square,edges([1,3]));
let basis_nodes = nodes('arc','triangle1','triangle2','square','brokensquare','house1','house2');
let basis_edges = edges(
  ['arc','triangle1'],['arc','triangle2'],['arc','square'],['square','brokensquare'],
  ['square','house1'],['square','house2'],['triangle1','house1']
);

//let basis_edges_label = edges_label(
  //['arc','triangle1'],['arc','triangle2'],['arc','square'],['square','brokensquare'],
  //['square','house1'],['square','house2'],['triangle1','house1']
//);

//console.dir(basis_edges);
//console.dir(basis_edges_label);

let basis = {info: {id: "basis"}, elements: _.union(basis_nodes,basis_edges)};
//let basis_label = {info: {id: "basis"}, elements: _.union(basis_nodes,basis_edges_label)};

// graphlib -> cytoscape-ready data with shape: {info, elements}
let gl_to_cy_data = (gl) => {
  let l_nodes = nodes(... _.map(gl.nodes(),n => [n,gl.node(n).label]));
  let l_edges = edges(... _.map(gl.edges(), ({v,w}) => [v,w,gl.edge({v,w})]));
  let data = gl.graph();
  let loaded = {info: (_.isString(data) ? {id: data} : data), elements: _.union(l_nodes,l_edges)};

  return loaded
}

module.exports = { gl_to_cy_data, demo: {basis} };