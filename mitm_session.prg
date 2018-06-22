

//ebbol kesobb lehet majd thread-eket csinalni
//teszteleshez jobb, ha  a listener kulon exe-ben van
//mert egyebkent az ujrainditaskor mindig varni kell a portra
//(ugyanis a resuseaddress sajnos nem hatasos)


function main(sck)
    mitmNew(val(sck)):loop
    