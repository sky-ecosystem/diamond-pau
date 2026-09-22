PATH := ~/.solc-select/artifacts/solc-0.8.34:$(PATH)
certora-beacon :; PATH=${PATH} certoraRun certora/Beacon.conf$(if $(rule), --rule $(rule),)$(if $(results), --wait_for_results all,)
certora-controller :; PATH=${PATH} certoraRun certora/Controller.conf$(if $(rule), --rule $(rule),)$(if $(results), --wait_for_results all,)
certora-facet-% :; PATH=${PATH} certoraRun certora/facets/$*.conf$(if $(rule), --rule $(rule),)$(if $(results), --wait_for_results all,)
