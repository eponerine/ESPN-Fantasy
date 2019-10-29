#region Globals

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

[string]$espnBaseUri = 'https://fantasy.espn.com'
[string]$espnApiUri  = "$espnBaseUri/apis/v3"

# Static for testing, plan to pass this eventually
[string]$espnCookieSWID    = "{XXXXXXXXXXXX}"
[string]$espnCookieESPN_S2 = "YYYYYYYY"

$webSession    = New-Object Microsoft.PowerShell.Commands.WebRequestSession

# Build SWID cookie and add to session
$cookieSWID        = New-Object System.Net.Cookie
$cookieSWID.Name   = "swid"
$cookieSWID.Value  = $espnCookieSWID
$cookieSWID.Domain = "fantasy.espn.com"
$cookieSWID.Path   = "/"
$webSession.Cookies.Add($cookieSWID)

# Build ESPN_S2 cookie and add to session
$cookieESPN_S2        = New-Object System.Net.Cookie
$cookieESPN_S2.Name   = "espn_s2"
$cookieESPN_S2.Value  = $espnCookieESPN_S2
$cookieESPN_S2.Domain = "fantasy.espn.com"
$cookieESPN_S2.Path   = "/"
$webSession.Cookies.Add($cookieESPN_S2)

#endregion Globals

#region Utilities

Function Get-EspnFantasyData {

    [CmdletBinding()]
    param (
        [string]$leagueID,
        [string]$leagueYear
    )

    # Hit ESPN's API for all the data
    $result = Invoke-RestMethod -Uri ("$espnApiUri/games/ffl/seasons/$leagueYear/segments/0/leagues/$leagueID" + "?view=mStandings&view=mTeam") `
                                -Method Get `
                                -WebSession $webSession

    return $result
}

#endregion Utilities

#region Functions

Function Get-EspnFantasyTeams {

    [CmdletBinding()]
    param (
        [string]$leagueID,
        [string]$leagueYear
    )

    # Get all the league data
    $leagueData = Get-EspnFantasyData -leagueID $leagueID -leagueYear $leagueYear
    
    # Get all the league members, link them to their teams, and create a custom object representing all of that
    $leagueTeams = [System.Collections.ArrayList]@()

    ForEach ($m in $leagueData.members) {

        # Find the cooresponding team
        $t = $leagueData.teams | ? owners -like $m.id

        # Create the custom object
        $teamObject = [PSCustomObject]@{

            AccountDisplayName = $m.displayName
            AccountFirstName   = $m.firstName
            AccountLastName    = $m.lastName
            AccountID          = $m.id
            TeamID             = $t.id
            TeamAbbreviation   = $t.abbrev
            TeamLocation       = $t.location
            TeamNickname       = $t.nickname
            TeamPointsFor      = $t.points
        }

        $leagueTeams.Add($teamObject) | Out-Null
    }

    return $leagueTeams
}

Function Get-EspnFantasyMatchupBoxscore {

    [CmdletBinding()]
    param (
        [string]$leagueID,
        [string]$leagueYear,
        [int]$weekNumber,
        [int]$teamId
    )

    # Get all the league data
    $leagueData = Get-EspnFantasyData -leagueID $leagueID -leagueYear $leagueYear

    # Pull out the specified week's scores
    $matchupResults = $leagueData.schedule | ? matchupPeriodId -eq $weekNumber

    # Loop thru each matchup to scrape the stuff we care about and add it to a cleaner list
    $boxScores = [System.Collections.ArrayList]@()

    ForEach ($m in $matchupResults) {

        # Build custom object
        $scoreObject = [PSCustomObject]@{

            awayTeamId       = $m.away.teamId
            awayTeamLocation = $leagueData.teams | ? id -eq $m.away.teamId | Select -ExpandProperty location
            awayTeamNickname = $leagueData.teams | ? id -eq $m.away.teamId | Select -ExpandProperty nickname
            awayTeamPoints   = $m.away.totalPoints
            homeTeamId       = $m.home.teamId
            homeTeamLocation = $leagueData.teams | ? id -eq $m.home.teamId | Select -ExpandProperty location
            homeTeamNickname = $leagueData.teams | ? id -eq $m.home.teamId | Select -ExpandProperty nickname
            homeTeamPoints   = $m.home.totalPoints
        }

        $boxScores.Add($scoreObject) | Out-Null
        
    }

    return $boxScores
}


Function Get-EspnFantasyWeekScores {

    [CmdletBinding()]
    param (
        [string]$leagueID,
        [string]$leagueYear,
        [int]$weekNumber,
        [int]$teamId
    )

    # Get all the league data
    $leagueData = Get-EspnFantasyData -leagueID $leagueID -leagueYear $leagueYear

    # Pull out the specified week's scores
    $matchupResults = $leagueData.schedule | ? matchupPeriodId -eq $weekNumber

    # Loop thru each matchup to scrape the stuff we care about and add it to a cleaner list
    $weekScores = [System.Collections.ArrayList]@()

    ForEach ($m in $matchupResults) {

        # Build custom objects
        $awayScoreObject = [PSCustomObject]@{
            teamId       = $m.away.teamId
            teamLocation = $leagueData.teams | ? id -eq $m.away.teamId | Select -ExpandProperty location
            teamNickname = $leagueData.teams | ? id -eq $m.away.teamId | Select -ExpandProperty nickname
            teamPoints   = $m.away.totalPoints
        }

        $homeScoreObject = [PSCustomObject]@{
            teamId       = $m.home.teamId
            teamLocation = $leagueData.teams | ? id -eq $m.home.teamId | Select -ExpandProperty location
            teamNickname = $leagueData.teams | ? id -eq $m.home.teamId | Select -ExpandProperty nickname
            teamPoints   = $m.home.totalPoints
        }

        # Add home and away to big flat list
        $weekScores.Add($awayScoreObject) | Out-Null
        $weekScores.Add($homeScoreObject) | Out-Null
    }

    return $weekScores
}

#endregion Functions