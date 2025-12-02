using System.Runtime.Serialization;

namespace SoapWebApi.Models;

[DataContract]
public class GeoCoordinates
{
    [DataMember]
    public double Latitude { get; set; }
        
    [DataMember]
    public double Longitude { get; set; } 
}