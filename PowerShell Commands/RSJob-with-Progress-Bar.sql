@(2,4,6,8,10,12,14,16) | Start-RSJob -Name {"Test_$_"} -Throttle 2 -ScriptBlock { start-sleep -Seconds $_ }

# Get all the running jobs
$jobs = Get-RSJob | ? {$_.Name -like 'Test_*'}
$runningjobs = ($jobs | ? {$_.State -ne 'Completed'}).Count
$total = $jobs.count


# Loop while there are running jobs
while($runningjobs -gt 0) {
    # Update progress based on how many jobs are done yet.
    write-progress -activity "Events" -status "$($total-$runningjobs)/$total jobs completed" -percentcomplete (($total-$runningjobs)/$total*100)

    # After updating the progress bar, get current job count
    $runningjobs = ($jobs | ? {$_.State -ne 'Completed'}).Count
}

$jobs | Remove-RSJob