using System.Runtime.Serialization;

namespace SoapWebApi.Models;

[DataContract]
public class GeoMapRequest
{
    [DataMember] 
    public GeoCoordinates TopLeft { get; set; } = null!;

    [DataMember] 
    public GeoCoordinates BottomRight { get; set; } = null!;
}