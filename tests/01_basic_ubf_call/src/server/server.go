package main

import (
	"atmi"
	"fmt"
	"os"
	"ubftab"
)

const (
	SUCCEED = 0
	FAIL    = -1
)

//TESTSVC service
func TESTSVC(ac *atmi.ATMICtx, svc *atmi.TPSVCINFO) {

	ret := SUCCEED

	//Get UBF Handler
	ub, _ := ac.CastToUBF(&svc.Data)

	//Print the buffer to stdout
	//fmt.Println("Incoming request:")
	ub.TpLogPrintUBF(atmi.LOG_DEBUG, "Incoming request:")

	//Resize buffer, to have some more space
	if err := ub.TpRealloc(1024); err != nil {
		fmt.Printf("TpRealloc() Got error: %d:[%s]\n", err.Code(), err.Message())
		ret = FAIL
		goto out
	}

	//Set some field
	if err := ub.BChg(ubftab.T_STRING_FLD, 0, "Hello World from Enduro/X service"); err != nil {
		fmt.Printf("Bchg() Got error: %d:[%s]\n", err.Code(), err.Message())
		ret = FAIL
		goto out
	}
	//Set second occurance too of the T_STRING_FLD field
	if err := ub.BChg(ubftab.T_STRING_FLD, 1, "This is line2"); err != nil {
		fmt.Printf("Bchg() 2 Got error: %d:[%s]\n", err.Code(), err.Message())
		ret = FAIL
		goto out
	}

out:
	//Return to the caller
	if SUCCEED == ret {
		ac.TpReturn(atmi.TPSUCCESS, 0, ub, 0)
	} else {
		ac.TpReturn(atmi.TPFAIL, 0, ub, 0)
	}
	return
}

//Server init
func Init(ac *atmi.ATMICtx) int {

	//Advertize TESTSVC
	if err := ac.TpAdvertise("TESTSVC", "TESTSVC", TESTSVC); err != nil {
		fmt.Println(err)
		return atmi.FAIL
	}

	return atmi.SUCCEED
}

//Server shutdown
func Uninit(ac *atmi.ATMICtx) {
	fmt.Println("Server shutting down...")
}

//Executable main entry point
func main() {
	//Have some context
	ac, err := atmi.NewATMICtx()

	if nil != err {
		fmt.Errorf("Failed to allocate cotnext!", err)
		os.Exit(atmi.FAIL)
	} else {
		//Run as server
		ac.TpRun(Init, Uninit)
	}
}
