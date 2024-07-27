Invoke-DbaDbShrink -SqlInstance 'TSQLPRD01' `
                    -Database AMGMusicAuthority,EntryAggregation,RoviTunes,VendorLinkProcess,VestaMusicProcessing,Workspace `
                    -FileType Log `
                    -StepSize 2048MB