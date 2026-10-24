*! wordlisten 0.2.0 25oct2026 -- public isolated-clip experiment, pure Stata/Mata
program define wordlisten, rclass
    version 16.1
    syntax using/ , MODEL(string) SAVING(string) [REPLACE]
    if "`replace'"=="" confirm new file `"`saving'"'
    confirm file `"`model'"'
    preserve
    quietly wavread16 using `"`using'"', clear
    if r(samplerate)!=16000 | r(channels)!=1 {
        display as error "wordlisten requires 16 kHz mono PCM16 WAV"
        exit 198
    }
    quietly findfile wordcore.mata
    quietly run `"`r(fn)'"'
    quietly findfile clipcore.mata
    quietly run `"`r(fn)'"'
    mata: spc_listen(st_local("model"))
    quietly save `"`saving'"', `replace'
    list recognized_label decision_status, noobs abbreviate(24)
    restore
    return scalar candidates = `wl_candidates'
    return scalar accepted = `wl_accepted'
    return scalar cutoff = `wl_cutoff'
    return scalar minimum_gap = `wl_gap'
    return local saved `"`saving'"'
end

version 16.1
capture mata: mata drop spc_listen()
mata:
mata set matastrict on
void spc_listen(string scalar model)
{
    real scalar fh, calibrated, count
    real rowvector config, bounds, decision, output
    real colvector x
    real matrix bank,index,F,scores
    string scalar signature,state,result,response,candidate
    string rowvector labels
    fh=fopen(model,"r")
    signature=fgetmatrix(fh); config=fgetmatrix(fh); labels=fgetmatrix(fh)
    bank=fgetmatrix(fh); index=fgetmatrix(fh); fclose(fh)
    slk_require(signature=="mata_public_words_v1","expected public isolated-clip model")
    slk_require(cols(config)==4 & config[1]==16000 & config[2]==13,"unsupported model configuration")
    slk_require(all(labels:==("yes","no","stop")) & cols(bank)==13,"expected yes/no/stop model")
    x=st_data(.,"amplitude1"); bounds=spc_bounds(x)
    count=(cols(bounds)==2); calibrated=(config[3]>=0 & config[4]>=0)
    output=J(1,11,.); candidate=""
    if (!count) {
        output[1,1..3]=(0,0,rows(x)/16000); output[1,10]=0
        state="no_signal"; result="no signal"; response="No usable signal found."
    }
    else {
        F=slk_features(x[bounds[1]..bounds[2]],16000)
        scores=slk_scores(F,bank,index)
        decision=slk_decide(scores,config[3],config[4])
        output=(1,(bounds[1]-1)/16000,bounds[2]/16000,scores[,2]',decision,decision[3]-decision[2])
        candidate=labels[decision[1]]
        if (!calibrated) {
            state="uncalibrated";result="pending";response="Acceptance criteria are not calibrated."
        }
        else if (decision[4]==1) {
            state="accepted";result=candidate;response="Recognized "+result+"."
        }
        else {
            state=decision[2]>config[3] ? "distance_reject" : "ambiguous"
            result="unrecognized";response="Word not recognized. Please try again."
        }
    }
    stata("clear");st_addobs(1)
    (void)st_addvar("double",("segment","start_sec","end_sec","d_yes","d_no","d_stop","candidate_id","best_distance","second_distance","accepted","distance_gap"))
    st_store(.,(1..11),output)
    (void)st_addvar("str12","candidate_label")
    (void)st_addvar("str24",("recognized_label","decision_status"))
    (void)st_addvar("strL","response_text")
    st_sstore(.,"candidate_label",candidate)
    st_sstore(.,"recognized_label",result)
    st_sstore(.,"decision_status",state)
    st_sstore(.,"response_text",response)
    (void)st_addvar("double",("cutoff","minimum_gap"))
    st_store(.,"cutoff",config[3]);st_store(.,"minimum_gap",config[4])
    st_local("wl_candidates",strofreal(count))
    st_local("wl_accepted",strofreal(output[10]==1))
    st_local("wl_cutoff",strofreal(config[3],"%21.16g"))
    st_local("wl_gap",strofreal(config[4],"%21.16g"))
}
end
