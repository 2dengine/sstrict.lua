return function(item, other) 
  if --[[other.isSlope or]] other.isSolid then
    return "cross"
  end
end