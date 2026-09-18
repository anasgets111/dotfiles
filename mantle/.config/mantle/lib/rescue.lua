-- The failed reload's text, or `""`. Gate on this, not `is_rescue`: a refused session lock raises
-- the flag with its own reason and deserves the same circle.
return mantle.rescue:map(function(r)
    return (r and r.error_log) or ""
end)
