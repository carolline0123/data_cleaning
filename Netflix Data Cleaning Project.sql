/*

Cleaning Data with SQL Queries
Dataset Source: https://www.kaggle.com/datasets/shivamb/netflix-shows

*/

USE netflix_titles;
ALTER TABLE netflix_titles_dataset 
RENAME NetflixTitles;

-- Create Duplicate of Raw Data

ALTER TABLE NetflixTitles
RENAME NetflixTitlesRawData;

CREATE TABLE NetflixTitles
LIKE NetflixTitlesRawData;

INSERT NetflixTitles
SELECT *
FROM NetflixTitlesRawData;

-- Standarize Date Format (Converting Text Data Type into Date)

UPDATE NetflixTitles
	SET date_added = CASE 
		WHEN date_added LIKE '%-%-%' THEN STR_TO_DATE(date_added, '%d-%b-%y')
		ELSE STR_TO_DATE(date_added, '%M %d, %Y')
    	END;

ALTER TABLE NetflixTitles
MODIFY COLUMN date_added DATE;

-- Extract Primary Production Country of a Movie into a Seperate Column

UPDATE NetflixTitles
SET country = TRIM(LEADING ', ' FROM country);

SELECT 
	country,
	SUBSTRING_INDEX(country, ',', 1) AS primary_country
FROM NetflixTitles;

ALTER TABLE NetflixTitles
ADD primary_country varchar(100);

UPDATE NetflixTitles
SET primary_country = SUBSTRING_INDEX(country, ',', 1);

SELECT 
	primary_country
FROM NetflixTitles
GROUP BY primary_country
ORDER BY 1;

-- Identifying Duplicate Records

SELECT 
	COUNT(DISTINCT show_id) AS unique_ids,
	COUNT(show_id) AS all_ids
FROM NetflixTitles;

SELECT
	COUNT(DISTINCT title) AS unique_titles,
	COUNT(title) AS all_titles
FROM NetflixTitles;

WITH NetflixDuplicateCTE AS (
	SELECT *,
		ROW_NUMBER() OVER(PARTITION BY date_added, `type`, title, release_year, duration) AS row_num
	FROM NetflixTitles
)

SELECT *
FROM NetflixDuplicateCTE
WHERE row_num > 1;

-- Removing Duplicate Records 

DROP TABLE `NetflixTitlesUpdated`;

CREATE TABLE `NetflixTitlesUpdated` (
  `show_id` text,
  `type` text,
  `title` text,
  `director` text,
  `cast` text,
  `country` text,
  `date_added` date DEFAULT NULL,
  `release_year` int DEFAULT NULL,
  `rating` text,
  `duration` text,
  `listed_in` text,
  `description` text,
  `primary_country` varchar(255) DEFAULT NULL,
  `row_num` int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SELECT * FROM NetflixTitlesUpdated;

INSERT INTO NetflixTitlesUpdated
SELECT *,
	ROW_NUMBER() OVER(PARTITION BY date_added, `type`, title, release_year, duration) AS row_num
FROM NetflixTitles;

DELETE
FROM NetflixTitlesUpdated
WHERE row_num > 1;

-- Check

SELECT *
FROM NetflixTitlesUpdated
WHERE title = '9-Feb';

-- Pupulate Nulls with the Name of the Director who Have Worked with the Same Cast a Few Times
SELECT
	COUNT(DISTINCT cast)
FROM NetflixTitlesUpdated;

SELECT 
	n1.director, 
	n1.cast, 
	n2.director, 
	n2.cast, 
	ROW_NUMBER() OVER(PARTITION BY n1.director, n1.cast, n2.director, n2.cast) AS row_num_2
FROM NetflixTitlesUpdated n1
JOIN NetflixTitlesUpdated n2
	ON n1.cast = n2.cast
WHERE (n1.director IS NULL OR n1.director = '')
	AND n2.director IS NOT NULL;

WITH NetflixTemp AS (
	SELECT 
		n2.director, 
		n2.cast, 
        	ROW_NUMBER() OVER(PARTITION BY n2.director, n2.cast) AS row_num_2
	FROM NetflixTitlesUpdated n1
	JOIN NetflixTitlesUpdated n2
		ON n1.cast = n2.cast
	WHERE (n1.director IS NULL OR n1.director = '')
		AND n2.director IS NOT NULL)

SELECT *
FROM NetflixTemp
WHERE row_num_2 > 5;

UPDATE NetflixTitlesUpdated
SET director = 'Alastair Fothergill'
WHERE `cast` = 'David Attenborough' AND director IS NULL;

UPDATE NetflixTitlesUpdated
SET director = 'Rajiv Chilaka'
WHERE `cast` = 'Vatsal Dubey, Julie Tejwani, Rupa Bhimani, Jigna Bhardwaj, Rajesh Kava, Mousam, Swapnil' AND director IS NULL;

-- Breaking out duration column to duration_show_seasons for TV Shows and duration_movie_mins Column for Movies, and converting it to INT for further analysis

SELECT 
	duration,
	CASE
		WHEN type = 'Movie' THEN SUBSTRING_INDEX(duration, ' ', 1)
		ELSE SUBSTRING_INDEX(duration, ' ', 1) 
    	END
FROM NetflixTitlesUpdated;

CREATE TABLE `netflixtitlesupdated_2` (
  `show_id` text,
  `type` text,
  `title` text,
  `director` text,
  `cast` text,
  `country` text,
  `date_added` date DEFAULT NULL,
  `release_year` int DEFAULT NULL,
  `rating` text,
  `duration` text,
  `listed_in` text,
  `description` text,
  `primary_country` varchar(255) DEFAULT NULL,
  `row_num` int DEFAULT NULL,
  `duration_movie_mins` int,
  `duration_show_seasons` int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SELECT * FROM netflixtitlesupdated_2;

INSERT INTO netflixtitlesupdated_2
SELECT *,
	CASE
		WHEN type = 'Movie' THEN SUBSTRING_INDEX(duration, ' ', 1)
		ELSE NULL
	END AS duration_movie_mins,
	CASE 
		WHEN type = 'TV Show' THEN SUBSTRING_INDEX(duration, ' ', 1)
		ELSE NULL
	END AS duration_show_seasons
FROM NetflixTitlesUpdated;

SELECT * FROM netflixtitlesupdated_2;

SELECT 
	title, 
	duration, 
	release_year, 
	duration_show_seasons
FROM netflixtitlesupdated_2
WHERE type = 'TV Show' AND duration IS NOT NULL
ORDER BY 4 DESC;
