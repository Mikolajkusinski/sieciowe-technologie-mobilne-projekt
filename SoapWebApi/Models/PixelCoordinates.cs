using System.Runtime.Serialization;

namespace SoapWebApi.Models;

[DataContract]
public class PixelCoordinates
{
    [DataMember] 
    public int X { get; set; }

    [DataMember] 
    public int Y { get; set; }
}