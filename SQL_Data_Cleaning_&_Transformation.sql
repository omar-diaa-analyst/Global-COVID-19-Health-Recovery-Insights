/*
Covid 19 Data Exploration 

Skills used: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types

*/
USE testdb
GO

SELECT * FROM testdb..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY 3,4;


SELECT * FROM testdb..CovidVaccinations
WHERE continent IS NOT NULL
ORDER BY 3,4;

--Select Data That We Are Going Be Starting With

SELECT continent,location, date, total_cases, new_cases, total_deaths,new_deaths, population 
FROM testdb..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY 1,2;

--Total Cases VS Total Deaths
--Show like lihood of dying is you contract covid in your country

SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS DeathPrecentage
FROM testdb..CovidDeaths
WHERE location like '%Egypt%' 
AND continent IS NOT NULL
ORDER BY 1,2;

--Total Cases VS Population
--Shows What Percentage of Population infected With Covid

SELECT location, date, total_cases, population , (total_cases/population)*100 AS  PercentPopulationInfected
FROM testdb..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY 1,2;

--Countries With Highest Infection Rate Compared To population

SELECT  location, population, date,MAX(total_cases) AS HighestInfectionCount , MAX(total_cases/population)*100 AS PercentPopulationInfected
FROM testdb..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location , population, date
ORDER BY PercentPopulationInfected DESC;

--Countries With Highest Deaths Count Per population

SELECT location, SUM(CAST(total_deaths AS int)) AS TotalDeathCount
FROM testdb..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY TotalDeathCount DESC;

--Breaking Things Down By Continent
--Showing contintents with the highest death count per population

SELECT continent, SUM(CAST(total_deaths AS int)) AS TotalDeathCount
FROM testdb..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY TotalDeathCount DESC;

--Global Numbers

SELECT SUM(new_cases) AS Total_Cases , SUM(CAST(new_deaths AS int)) AS Total_Deaths, SUM(CAST(new_deaths AS int)) / SUM(new_cases)*100 AS Deathprecentage
FROM testdb..CovidDeaths
WHERE continent IS NOT NULL
--GROUP BY date
ORDER BY 1,2;

--Total Population VS Vaccinations
--Shows Percentage of Population That Has Recieved at heast one Covid Vaccine.

SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(CAST(vac.new_vaccinations AS int )) OVER (PARTITION BY dea.location ORDER BY dea.location , dea.date ) AS RollingPeopleVaccinated

FROM testdb..CovidDeaths  dea
JOIN 
testdb..CovidVaccinations vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY 2,3


-- Using CTE to perform Calculation on Partition By in previous query


WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
AS
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (PARTITION BY dea.Location ORDER BY  dea.location, dea.Date) AS RollingPeopleVaccinated
FROM testdb..CovidDeaths dea
Join testdb..CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
WHERE dea.continent is not null 
--ORDER BY 2,3
)
SELECT *, (RollingPeopleVaccinated/Population)*100 AS PrecentagePeopleVaccinated
FROM PopvsVac

USE testdb;
GO

-- 1. Drop the old table if it already exists to prevent duplication or schema conflicts
DROP TABLE IF EXISTS dbo.Fact_Covid_Master;
GO

-- 2. Merge datasets and create the new Master Fact Table automatically using SELECT INTO
SELECT 
    dea.continent AS Continent, 
    dea.location AS Location, 
    CONVERT(DATE, dea.date) AS Date, -- Clean date format for seamless Power BI optimization
    dea.population AS Population, 
    ISNULL(dea.total_cases, 0) AS TotalCases, 
    ISNULL(dea.new_cases, 0) AS NewCases, 
    ISNULL(dea.total_deaths, 0) AS TotalDeaths, 
    ISNULL(dea.new_deaths, 0) AS NewDeaths,
    ISNULL(vac.new_vaccinations, 0) AS NewVaccinations,

    -- Using BIGINT to prevent data overflow since global vaccination counts reach billions
    
    SUM(CONVERT(BIGINT, ISNULL(vac.new_vaccinations, 0))) OVER (
        PARTITION BY dea.location 
        ORDER BY dea.location, dea.date
    ) AS RollingPeopleVaccinated

INTO dbo.Fact_Covid_Master -- The target database table for Power BI Live/Import connection
FROM testdb..CovidDeaths dea
JOIN testdb..CovidVaccinations vac
    ON dea.location = vac.location
    AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;
GO

-- 3. Verify that the Master Fact Table was successfully created and preview rows
SELECT * FROM dbo.Fact_Covid_Master;