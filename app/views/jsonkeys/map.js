function(doc) {
  function emitkeys(o) {
    var keys = Object.keys(o), len = keys.length, i;
    for (i=0; i < len; i++) {
      if (! o.push) emit(keys[i], 1);
      if (typeof(o[keys[i]]) == 'object') emitkeys(o[keys[i]]);
    }
  }
  if (doc.type == 'json-file' && typeof(doc.value) == 'object') emitkeys(doc.value);
}
