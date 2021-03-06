###################################
# Projet de s�ries temporelles
# Matthieu Bricaire - Yseult Masson
###################################


###################################
# Chargement des librairies utiles
###################################

library(tseries)
library(forecast)
library(fUnitRoots)

###########################
# Partie 1 : Les donn�es
###########################

# 1.1 : S�rie choisie

#Remarque : sauvegarder le code et les donn�es dans un m�me dossier, 
#et sp�cifier le 'working directory' de la session sur 'Source file location'.

#On charge les donn�es, et on nomme les colonnes du Dataframe
data = read.csv("valeurs_mensuelles.csv", sep=";", col.names = c('Dates', 'Indice', 'Codes'))

#On enl�ve les trois premi�res lignes, qui ne sont pas pertinentes
#On enl�ve �galement la troisi�me colonne, qui n'est pas utile
data = data[-(1:3), 1:2 ]

#On r�initialise l'index du DataFrame
rownames(data) = NULL

#On transforme la colonne 'Dates' de sorte que les dates soient bien 
#reconnues comme telles
data$Dates <- as.Date(paste(data$Dates,1,sep="-"), format="%Y-%m-%d")

#On cr�� deux nouvelles colonnes, contenant les ann�es et les mois
#associ�s aux dates de la s�rie
annee = as.numeric(format(data$Dates, format = "%Y")) 
mois = format(data$Dates, format = '%m')

#On ajoute les nouvelles colonnes au Dataframe initial
data = cbind(data, annee, mois)

#On convertit les valeurs de l'indice en donn�es num�riques
data$Indice <- as.numeric(data$Indice)

#On cr�� la s�rie temporelle associ�e aux valeurs prises par l'indice
#de production
Xt.ts <- ts(data$Indice, start=c(1990, 1), end=c(2022, 2), frequency=12)

#On trace la s�rie, et on sauvegarde le graphique obtenu
png('Serie_initiale.png', width=600, height=450)
plot.ts(Xt.ts, xlab="Ann�es", ylab="Indice")
dev.off()

# 1.2 : transformation de la s�rie

#R�gression lin�aire de l'indice sur les dates
regLinIndice=lm(Xt.ts ~ Dates,data=data)
summary(regLinIndice)

#La r�gression pr�c�dente met en �vidence une tendance lin�aire 
#croissante de la s�rie (coefficient significativement positif)
#A priori, la s�rie ne semble donc pas stationnaire

#On v�rifie la non stationnarit� de la s�rie � l'aide de tests ADF et KPSS

adf.test(Xt.ts)
#La p-value associ�e � ce test vaut 0.70
#L'hypoth�se nulle (non stationnarit� de la s�rie) n'est rejet�e
#� aucun niveau usuel

kpss.test(Xt.ts)
#La p-value associ�e � ce test est inf�rieure � 0.01
#L'hypoth�se nulle (stationnarit� de la s�rie) est rejet�e
#� tous les niveaux usuels

#Conclusion : la s�rie n'est pas stationnaire, on va la diff�rencier
#pour tenter de la rendre stationnaire

#Diff�renciation de la s�rie, ajout d'un NA pour la valeur
#de "l'accroissement 0", qui n'est pas d�fini
diff_indice.ts <- ts(c(NA,diff(data$Indice,1)), start=c(1990, 1), end=c(2022, 2), frequency=12)

#On v�rifie la stationnarit� de la s�rie diff�renci�e � l'aide de tests ADF et KPSS

adf.test(na.omit(diff_indice.ts))
#La p-value associ�e � ce test est inf�rieure � 0.01
#L'hypoth�se nulle (non stationnarit� de la s�rie) est rejet�e
#� tous les niveaux usuels

kpss.test(na.omit(diff_indice.ts))
#La p-value associ�e � ce test est sup�rieure � 0.1
#L'hypoth�se nulle (stationnarit� de la s�rie) n'est rejet�e
#� aucun niveau usuel 


#Conclusion : on peut consid�rer la s�rie diff�renci�e comme stationnaire

#On trace la s�rie diff�renci�e, et on sauvegarde le graphique obtenu
png('Serie_differenciee.png', width=600, height=450)
plot.ts(diff_indice.ts, xlab="Ann�es", ylab="Accroissements")
dev.off()

###########################
# Partie 2 : Mod�les ARMA
###########################

# 2.1 : choix d'un mod�le ARMA(p,q) pour la s�rie diff�renci�e

#On trace l'autocorr�logramme de la s�rie diff�renci�e
png('Autocorr�logramme_serie_differenciee.png', width=400, height=300)
acf(diff_indice.ts,na.action=na.omit)
dev.off()

#L'autocorr�logramme semble ne plus pr�senter de "pics" significatifs au del� de l'ordre 2
#De plus, nous choisissons d'ignorer les pics pour des retards sup�rieurs � 6
#Nous allons chercher 0 <= q <= 2 (q_max=2)

#On trace l'autocorr�logramme partiel de la s�rie diff�renci�e
png('Autocorr�logramme_partiel_serie_differenciee.png', width=400, height=300)
pacf(diff_indice.ts,na.action=na.omit)
dev.off()

#L'autocorr�logramme partiel semble ne plus pr�senter de "pics" significatifs au del� de l'ordre 3
#De plus, nous choisissons d'ignorer les pics pour des retards sup�rieurs � 6
#Nous allons chercher 0 <= p <= 3 (p_max=3)

#Cr�ation de la grille de param�tres
grille=expand.grid(p=seq(0,3),q=seq(0,2)) 

#On supprime l'ARMA(0,0), que l'on ne teste pas
grille=grille[-c(1),] 

#On cr�� un Dataframe qui regroupe les diff�rentes combinaisons 
#de param�tres � tester
tableau_modeles=data.frame("p"=grille$p,"q"=grille$q)

#On enl�ve le NA au d�but de la s�rie diff�renci�e
diff_indice_2.ts = na.omit(diff_indice.ts)

#On teste toutes les combinaisons (p,q) de la grille
#On ajoute les scores BIC et AIC de chaque mod�le au Dataframe tableau_modeles
for (i in (1:nrow(grille))){
  modTemp=try(arima(diff_indice_2.ts,order=c(tableau_modeles$p[i],0,tableau_modeles$q[i]),include.mean = T))
  tableau_modeles$AIC[i]=if (class(modTemp)=="try-error") NA else modTemp$aic
  tableau_modeles$BIC[i]=if (class(modTemp)=="try-error") NA else BIC(modTemp)
}

#On s�lectionne l'ARMA qui minimise le crit�re AIC
minAIC=which.min(tableau_modeles$AIC)
tableau_modeles[minAIC,]

#La minimisation du crit�re AIC conduit � s�lectionner le mod�le MA(2)
#L'AIC de ce mod�le vaut 1334.319

#On s�lectionne l'ARMA qui minimise le crit�re BIC
minBIC=which.min(tableau_modeles$BIC)
tableau_modeles[minBIC,]

#La minimisation du crit�re BIC conduit � s�lectionner le mod�le MA(2)
#Le BIC de ce mod�le vaut 1350.132

#On appelle le mod�le retenu : il s'agit d'un MA(2) pour la s�rie diff�renci�e
selected_model=arima(diff_indice_2.ts,order=c(tableau_modeles$p[minBIC],0,tableau_modeles$q[minBIC]),include.mean = T)
selected_model

#On va tester la significativit� du mod�le

#On commence par r�cup�rer les statistiques de test associ�es
#aux coefficients estim�s
t=selected_model$coef/sqrt(diag(selected_model$var.coef))

#On calcule les p-valeurs associ�es aux statistiques de test (formule pour un test bilat�ral)
pval=(1-pnorm(abs(t)))*2

#On regroupe les coefficients, les �carts-types, les statistiques 
#de test et les p-valeurs dans un DataFrame
results=rbind(coef=selected_model$coef,se=sqrt(diag(selected_model$var.coef)),t,pval)

#Conclusion : les coefficients du mod�le MA(2) sont significatifs � 
#tous les niveaux usuels (notamment le coefficient ma2).

#Pour que le mod�le soit valide, il faut �galement que les r�sidus se 
#comportent comme un bruit blanc

#On repr�sente graphiquement les r�sidus du mod�le, on sauvegarde 
#le graphique ainsi obtenu
png('Residus_modele_MA2.png', width=400, height=300)
plot(selected_model$residuals)
dev.off()

#On repr�sente graphiquement les autocorr�lations des r�sidus, on 
#sauvegarde le graphique ainsi obtenu
png('Autocorr�lations_modele_MA2.png', width=400, height=300)
plot(acf(selected_model$residuals))
dev.off()

#Les deux graphiques pr�c�dents semblent montrer que les r�sidus du
#mod�le se comportent bien comme un bruit blanc

#On teste l'absence d'autocorr�lation des r�sidus avec des tests de Box-Pierce
#On commence � tester l'absence d'autocorr�lation � partir de p+q+1=3
#On va jusqu'� 22, de sorte � avoir 22-2=20 autocorr�lations test�es
bpTest=lapply(seq(3,22),Box.test,x=selected_model$residuals,type="Box-Pierce",fitdf=2)

#Le test de Box-Pierce ne rejette jamais l'hypoth�se nulle (absence d'autocorr�lation des r�sidus)
#Il semble donc ne pas y avoir d'autocorr�lation des r�sidus

#On confirme cette impression avec des tests de Ljung-Box, plus performants que les tests de Box-Pierce 
lbTest=lapply(seq(3,22),Box.test,x=selected_model$residuals,type="Ljung-Box",fitdf=2)

#Le test de Ljung-Box ne rejette jamais l'hypoth�se nulle (absence d'autocorr�lation des r�sidus)

#Les r�sultats des test pr�c�dents permettent d'affirmer qu'il
#n'y a pas d'autocorr�lation au sein des r�sidus

#Conclusion : les coefficients du mod�le MA(2) sont significatifs
#� tous les niveaux usuels, et les r�sidus du mod�le se comportent
#comme un bruit blanc. Le mod�le MA(2) est donc valide.

###########################
# Partie 3 : Pr�vision
###########################

#On pr�voit les valeurs de la s�rie diff�renci�e
#aux horizons T+1 et T+2 (mars et avril 2022), et les r�gions de confiance � 95% associ�es
prevision = forecast(selected_model, h=2, level=0.95)

#On trace les pr�visions pr�c�demment calcul�es, et on sauvegarde le graphique obtenu
#Pour plus de lisibilit�, on se restreint � l'affichage 
#de l'intervalle de temps 2020-2022

png('Pr�visions_modele_MA(2).png', width=400, height=300)
plot(prevision, xlim=c(2020, 2022.2), ylim=c(-3, 3.9), xlab='Ann�es', ylab='Accroissements')
dev.off()

