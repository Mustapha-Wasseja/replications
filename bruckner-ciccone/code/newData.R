##### Clean updated data on commodity prices, income growth, and conflict ####
# This version:  25-08-2015
# First version: 23-06-2015
setwd("/Replications/2010_Bruckner_Ciccone")

## Libraries
library(countrycode)
library(DataCombine)
library(data.table)
library(reshape)
library(WDI)

## Data
imf<-read.csv("raw_data/imf.csv",header=TRUE,row.names=NULL,stringsAsFactors=FALSE,sep=",")
gem<-read.csv("raw_data/gem.csv",header=TRUE,row.names=NULL,stringsAsFactors=FALSE,sep=",")
oecd<-read.csv("raw_data/oecd.csv",header=TRUE,row.names=NULL,stringsAsFactors=FALSE,sep=",")
dots<-read.csv("raw_data/DOTS.csv",header=TRUE,row.names=NULL,stringsAsFactors=FALSE,sep=",")
load("raw_data/ucdpConflict.rdata")

#### Calculate price index ####

## Drop date
imf$Date<-gem$Time<-NULL

## Calculate price series for livestock and coffee
imf$Livestock=.72*imf$Lamb+.09*imf$Swine+.09*imf$Beef
imf$Coffee=.45*imf$Coffee_Arabica+.55*imf$Coffee_Robusta

imf$Lamb<-imf$Beef<-imf$Swine<-imf$Coffee_Robusta<-imf$Coffee_Arabica<-NULL

## Aggregate data to yearly means
imf.yr<-aggregate(.~year,imf,mean)
gem.yr<-aggregate(.~year,gem,mean)

prices<-merge(imf.yr,gem.yr)

## Set 1990 value equal to one
m<-as.matrix(prices[,-1])
prices<-data.frame(t(t(m)/m[11,]))
prices$year<-1980:2015

## Create data frame with weights
# This is based on the information given in Table A1
country<-c("Angola",rep("Benin",2),rep("Botswana",2),rep("Burkina Faso",2)
           ,rep("Burundi",2),rep("Cameroon",6),
           rep("Central African Republic",4),"Chad",
           rep("Democratic Republic of the Congo",2),"Republic of Congo",
           rep("Ethiopia",2),rep("Gabon",2),rep("Gambia",3),rep("Ghana",4),
           rep("Guinea",4),rep("Guinea-Bissau",5),rep("Ivory Coast",4),
           rep("Kenya",4),rep("Liberia",3),rep("Madagascar",5),rep("Malawi",2),
           "Mali",rep("Mauritania",2),rep("Mozambique",3),rep("Namibia",4),
           "Niger","Nigeria",rep("Rwanda",2),rep("Senegal",5),
           rep("Sierra Leone",4),"Somalia",rep("South Africa",3),rep("Sudan",2),
           rep("Swaziland",2),rep("Tanzania",4),rep("Togo",2),"Uganda",
           "Zambia",rep("Zimbabwe",4))
commodities<-c("Oil",
               "Cotton","Oil",
               "Nickel","Copper",
               "Cotton","Gold",
               "Coffee","Tea",
               "Oil","Wood","Cocoa","Aluminium","Coffee","Cotton",
               "Coffee","Wood","Cotton","Tobacco",
               "Cotton",
               "Copper","Oil",
               "Oil",
               "Coffee","Sugar",
               "Oil","Wood",
               "Groundnuts","Fish","Cotton",
               "Cocoa","Aluminium","Gold","Wood",
               "Aluminium","Coffee","Gold","Cotton",
               "Oil","Fish","Banana","Wood","Cotton",
               "Cocoa","Wood","Coffee","Oil",
               "Tea","Oil","Coffee","Fish",
               "Iron","Coffee","Cocoa",
               "Coffee","Fish","Sugar","Cotton","Oil",
               "Tobacco","Tea",
               "Cotton",
               "Iron","Fish",
               "Fish","Cotton","Sugar",
               "Fish","Uranium","Gold","Copper",
               "Uranium",
               "Oil",
               "Coffee","Gold",
               "Oil","Groundnuts","Fish","Phosphates","Cotton",
               "Aluminium","Cocoa","Coffee","Fish",
               "Livestock",
               "Gold","Iron","Aluminium",
               "Cotton","Sugar",
               "Sugar","Cotton",
               "Cotton","Sugar","Coffee","Gold",
               "Cotton","Phosphates",
               "Coffee",
               "Copper",
               "Tobacco","Iron","Cotton","Copper")
share<-c(.93,
         .42,.22,
         .10,.06,
         .57,.2,
         .75,.10,
         .50,.09,.08,.07,.08,.03,
         .11,.19,.11,.01,
         .85,
         .46,.1,
         .85,
         .45,.02,
         .75,.11,
         .20,.32,.03,
         .29,.18,.12,.11,
         .64,.06,.02,.01,
         .14,.28,.50,.04,.02,
         .33,.16,.09,.09,
         .19,.13,.14,.02,
         .62,.06,.03,
         .13,.14,.07,.04,.01,
         .68,.11,
         .62,
         .55,.35,
         .36,.08,.07,
         .18,.02,.02,.01,
         .83,
         .93,
         .61,.2,
         .12,.17,.28,.06,.01,
         .19,.15,.04,.01,
         .9,
         .5,.36,.15,
         .42,.06,
         .22,.02,
         .18,.19,.13,.05,
         .21,.44,
         .74,
         .88,
         .24,.10,.06,.02)

weights<-data.table(country=country,item=commodities,share=share,key="item")

## Calculate the weights
# Get column names of all the commodity types
prices<-data.table(prices)
vars<-names(prices)[!names(prices) %in% "year"]    

# Unstack the items and create a "long" table
prices<-data.table(year=prices[,year], stack(prices,vars),key="ind")

# Rename the columns
setnames(prices,c("values","ind"),c("price","item"))

# Join the weights and prices tables,
# multiply the share by the price, and sum by country and date:
ind<-weights[prices,allow.cartesian=T][,list(index=sum(share*price)),
                                  by=list(country,year)]

## Calculate variables
ind<-data.frame(ind[order(ind$country,ind$year),])

# Lag of the commodity price index
ind<-slide(ind,Var="index",
          GroupVar="country",
          NewVar="index.l",slideBy=-1)
ind<-slide(ind,Var="index",
          GroupVar="country",
          NewVar="index.l3",slideBy=-3)

# Growth rate
ind$index.g<-(ind$index-ind$index.l)/ind$index.l

# Lagged growth rates
ind<-slide(ind,Var="index.g",
          GroupVar="country",
          NewVar="index.g.l",slideBy=-1)
ind<-slide(ind,Var="index.g",
          GroupVar="country",
          NewVar="index.g.l2",slideBy=-2)

# 3-year commodity growth rate
ind$ind<-(ind$index-ind$index.l3)/ind$index.l3
ind$ccode<-countrycode(ind$country,"country.name","iso3c",warn=TRUE)

#### Calculate OECD index ####

## Data from wide to long
dots<-dots[,c(1,3,7:17)]
colnames(dots)[3:13]<-1985:1995
md<-melt(dots,id=c("Country","Partner.Country"))
colnames(md)<-c("oecd.partner","country","year","import_value")
im<-na.omit(md[md$year==1990,])

## For ease change Belgium-Luxembourg to Belgium
im[im$oecd.partner %in% "Belgium-Luxembourg","oecd.partner"]<-"Belgium"

## Include countries which were OECD member before 2010 (30)
im$oecd.iso2c<-countrycode(im$oecd.partner,"country.name","iso2c",warn=TRUE)
oecd$iso2c<-countrycode(oecd$country,"country.name","iso2c",warn=TRUE)
oecd.s<-oecd[oecd$membership_year<2010,]$iso2c
im<-im[im$oecd.iso2c %in% oecd.s & im$import_value>0,]

## 1990 GDP data African countries
iso2c<-countrycode(unique(im$country),"country.name","iso2c",warn=TRUE)
gdp<-WDIsearch("gdp",field="name",short=FALSE)
wdi<-WDI(iso2c,gdp[82,1],start=1990,end=1990)

# Merge data
im$iso2c<-countrycode(im$country,"country.name","iso2c",warn=TRUE)
im<-merge(im,wdi[,-2],all.x=TRUE)
colnames(im)[7]<-"gdp.1990"
im$exp.share<-im$import_value/im$gdp.1990

im<-im[order(im$country,im$oecd.partner),]

## GDP data OECD countries
wdi2<-WDI(oecd.s,gdp[86,1],start=1979,end=2013)
colnames(wdi2)[3]<-"gdp"
wdi2<-wdi2[order(wdi2$iso2c,wdi2$year),]

# Calculate growth rate
wdi2<-slide(wdi2,Var="gdp",
          GroupVar="iso2c",
          NewVar="gdp.l",slideBy=-1)
wdi2$gdp.g<-(wdi2$gdp-wdi2$gdp.l)/wdi2$gdp.l*100

oecd.gdp<-na.omit(wdi2[,c(2,4,6)])
colnames(oecd.gdp)<-c("partner","year","gdp.g")

## Calculate the weights
# Data table for weights
weights<-data.table(country=im$iso2c,partner=im$oecd.partner,share=im$exp.share,key="partner")

# Prepare GDP growth data OECD partners
oecd.gdp<-data.table(year=oecd.gdp$year,
                     partner=oecd.gdp$partner,
                     gdp.g=oecd.gdp$gdp.g,key="partner")

# Join the weights and GDP tables,
# multiply the share by the price, and sum by country and date:
ind2<-weights[oecd.gdp,allow.cartesian=T][,list(oecd.exp=sum(share*gdp.g)),
                                  by=list(country,year)]
ind2<-na.omit(ind2)

# Add ISO3C country code
ind2$ccode<-countrycode(ind2$country,"iso2c","iso3c",warn=TRUE)
ind2$country<-NULL

#### Data on income growth ####

## For Sub-Sahara African countries
iso2c<-countrycode(country,"country.name","iso2c",warn=TRUE)
gdp<-WDIsearch("gdp per capita",field="name",short=FALSE)
wdi<-WDI(iso2c,gdp[6,1],start=1980,end=2013)

wdi$ccode<-countrycode(wdi$iso2c,"iso2c","iso3c",warn=TRUE)
wdi$gdp.g<-wdi[,3]/100

#### Calculate conflict onset ####
af<-ucdpConflict[ucdpConflict$Region==4 & ucdpConflict$Year>=1980 &
                   ucdpConflict$TypeOfConflict!=2,]
af$ccode<-countrycode(af$Location,"country.name","iso3c",warn=TRUE)

# Dummies for conflict type
af$any<-1
af$minor<-as.numeric(af$IntensityLevel==1)
af$war<-as.numeric(af$IntensityLevel==2)
af$year<-af$Year

# Merge data
conflict<-aggregate(cbind(any,minor,war)~ccode+year,af,max)
data<-merge(ind,ind2,all.x=TRUE)
data<-merge(data,wdi[,-1:-3],all.x=TRUE)
data<-merge(data,conflict,all.x=TRUE)

# Set NAs to zero
data[is.na(data$any),]$any<-0
data[is.na(data$minor),]$minor<-0
data[is.na(data$war),]$war<-0

# Recode minor conflict variable
data[data$any==1 & data$war==0,]$minor<-1

# Lag of conflict
data<-data[order(data$ccode,data$year),]

data<-slide(data,Var="any",
          GroupVar="ccode",
          NewVar="any.l",slideBy=-1)

data<-slide(data,Var="minor",
          GroupVar="ccode",
          NewVar="minor.l",slideBy=-1)

data<-slide(data,Var="war",
          GroupVar="ccode",
          NewVar="war.l",slideBy=-1)

# NAs to zero again
data[is.na(data$any.l),]$any.l<-0
data[is.na(data$minor.l),]$minor.l<-0
data[is.na(data$war.l),]$war.l<-0

## Onset indicators

# All conflicts
data$onset<-NA
data$onset<-as.numeric(data$any==1 & data$any.l==0)
data[data$onset==0 & data$any==1,]$onset<-NA

# Minor conflicts
data$minor.onset<-NA
data$minor.onset<-as.numeric(data$minor==1 & data$minor.l==0)
data[data$minor.onset==0 & data$minor==1,]$minor<-NA

# War onset
data$war.onset<-NA
data$war.onset<-as.numeric(data$war==1 & data$war.l==0)
data[data$war.onset==0 & data$war==1,]$war.onset<-NA

# Subset data
df.New<-data[data$year>=1981 & data$year<=2013,]

# Drop Namibia before independence
df.New$na<-as.numeric(df.New$country=="Namibia" & df.New$year<=1989)
df.New<-df.New[df.New$na==0,];df.New$na<-NULL

## Save data
save(df.New,file="tidy_data/newData.Rdata")

