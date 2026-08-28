-- MySQL dump 10.13  Distrib 8.0.46, for Linux (x86_64)
--
-- Host: localhost    Database: asterisk
-- ------------------------------------------------------
-- Server version	8.0.46-0ubuntu0.24.04.3

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `conversations`
--

DROP TABLE IF EXISTS `conversations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `conversations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user1_id` int DEFAULT NULL,
  `user2_id` int DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `conversations`
--

LOCK TABLES `conversations` WRITE;
/*!40000 ALTER TABLE `conversations` DISABLE KEYS */;
INSERT INTO `conversations` VALUES (1,2,1,'2026-07-21 03:20:56'),(2,3,2,'2026-07-24 02:18:12');
/*!40000 ALTER TABLE `conversations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `messages`
--

DROP TABLE IF EXISTS `messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `messages` (
  `id` int NOT NULL AUTO_INCREMENT,
  `conversation_id` int DEFAULT NULL,
  `sender_id` int DEFAULT NULL,
  `content` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `messages`
--

LOCK TABLES `messages` WRITE;
/*!40000 ALTER TABLE `messages` DISABLE KEYS */;
INSERT INTO `messages` VALUES (1,1,2,'wei','2026-07-21 03:21:02'),(2,1,2,'apcb','2026-07-21 03:21:32'),(3,1,2,'hah','2026-07-21 04:15:27'),(4,1,1,'nande','2026-07-21 04:15:33'),(5,1,2,'baka','2026-07-22 02:44:34'),(6,1,1,'bakajanaino','2026-07-22 04:30:02'),(7,1,2,'oi','2026-07-22 04:30:14'),(8,1,2,'yo','2026-07-24 01:31:04'),(9,1,2,'wei','2026-07-24 01:35:04'),(10,1,1,'p','2026-07-24 01:41:57'),(11,1,2,'kokom','2026-07-24 01:56:10'),(12,1,2,'jika kamu suka aku ketik 1','2026-07-24 01:56:29'),(13,1,1,'1','2026-07-24 01:56:43'),(14,2,3,'yo speed','2026-07-24 02:18:19'),(15,2,2,'yo sir kdm','2026-07-24 02:18:30');
/*!40000 ALTER TABLE `messages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sip_buddies`
--

DROP TABLE IF EXISTS `sip_buddies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sip_buddies` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `host` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `secret` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `context` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `username` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `avpf` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `icesupport` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `encryption` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `rtcp_mux` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `transport` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `nat` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT 'yes',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sip_buddies`
--

LOCK TABLES `sip_buddies` WRITE;
/*!40000 ALTER TABLE `sip_buddies` DISABLE KEYS */;
INSERT INTO `sip_buddies` VALUES (1,'505','dynamic','505','internal','505','friend','yes','yes','yes','yes','ws,udp','yes'),(2,'606','dynamic','606','internal','606','friend','yes','yes','yes','yes','ws,udp','yes'),(3,'777','dynamic','777','internal','777','friend','yes','yes','yes','yes','ws,udp','yes');
/*!40000 ALTER TABLE `sip_buddies` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `username` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `phone_number` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sip_username` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sip_password` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fcm_token` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'monkey','505','$2a$10$cXYgaOf.E772WyMCI/.LxeuLZs7PI/vrkmWVuxDyICmdKvN5YLRf.','505','505',NULL),(2,'Speed','606','$2a$10$//9/WHHU9TSVxEYn3aqgmutzo8lR13Vnu3VF1jg1snbl.zEjCa7O6','606','606',NULL),(3,'Sir Dedi Mulyadi','777','$2a$10$WBlK3fth6xsmZbjQxDiAb.SYZyqQfda41iW2njIUWiGnA8VAvjCee','777','777',NULL);
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-07-24  2:23:05
