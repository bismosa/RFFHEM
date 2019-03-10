/opt/fhem/FHEM/%.pm: FHEM/%.pm
	sudo cp $< $@ 
98_UnitTest.pm: test/98_unittest.pm
	sudo cp $< /opt/fhem/FHEM/$@ || true
		
## deploylocal: /opt/fhem/FHEM/00_SIGNALduino.pm /opt/fhem/FHEM/10_FS10.pm /opt/fhem/FHEM/14_SD_WS.pm 98_UnitTest.pm /opt/fhem/FHEM/90_SIGNALduino_un.pm /opt/fhem/FHEM/lib/signalduino_protocols.hash
deploylocal : | 98_UnitTest.pm 
	sudo cp FHEM/*.pm /opt/fhem/FHEM/
	sudo cp FHEM/lib/*.pm /opt/fhem/FHEM/lib
	sudo cp test/*.json /opt/fhem/FHEM/lib || true
	sudo cp test/*.pm /opt/fhem/FHEM/lib
	sudo timeout 3 killall -qws2 perl || sudo killall -qws9 perl || true
	sudo rm /opt/fhem/log/fhem-*.log || true
	sudo cp test/fhem.cfg /opt/fhem/fhem.cfg
	sudo rm /opt/fhem/log/fhem.save || true
	TZ=Europe/Berlin 
#	cd /opt/fhem && perl -MDevel::Cover fhem.pl fhem.cfg && cd ${TRAVIS_BUILD_DIR}


test_%: fhem_start
	@d=$$(mktemp) && \
	echo BEFORE >> $$d 2>&1 && \
	test/test-runner.sh ${@F} >> $$d 2>&1 && \
	echo AFTER >> $$d 2>&1 && \
	flock /tmp/my-lock-file cat $$d && \
    rm $$d
#	$(eval COMMAND := test/test-runner.sh (@F))
#	$(eval OUTPUT_WITH_RC := $(shell IFS=:; test/test-runner.sh ${@F}; echo $$?))
#	$(eval OUTPUT_WITH_RC := $(shell test/test-runner.sh ${@F}; ret=$?; echo .; exit "$ret"))
#	$(eval RETURN_CODE := $(lastword $(OUTPUT_WITH_RC)))
#	$(eval OUTPUT := $(subst $(RETURN_CODE)QQQQ,,$(OUTPUT_WITH_RC)QQQQ))
#	@echo $(subst \x,${\n},${OUTPUT})

test_commandref:
	@echo === running commandref test ===
	git --no-pager diff --name-only ${TRAVIS_COMMIT_RANGE} | egrep "\.pm" | xargs -I@ echo -select @ | xargs --no-run-if-empty perl /opt/fhem/contrib/commandref_join.pl 

SOURCES := $(shell find ./test -maxdepth 1 -name 'test_*-definition.txt')
SOURCES := $(subst -definition.txt,,$(SOURCES))

init: 
	@echo $(SOURCES)

test_all: deploylocal fhem_start | test_commandref ${SOURCES}
	@echo === TEST_ALL done ===


fhem_start: deploylocal
	cd /opt/fhem && perl -MDevel::Cover fhem.pl fhem.cfg && cd ${TRAVIS_BUILD_DIR}
	@echo === ready for unit tests ===
fhem_kill:
	@echo === finished unit tests ===
	sudo timeout 30 killall -vw perl || sudo killall -vws9 perl

test:  | fhem_start test_all 
	@echo === running unit tests ===
	$(MAKE) 

