using System.Runtime.Serialization;

namespace SoapWebApi.Models;

[DataContract]
public class PixelMapRequest
{
    [DataMember] 
    public PixelCoordinates TopLeft { get; set; } = null!;

    [DataMember] 
    public PixelCoordinates BottomRight { get; set; } = null!;

    [DataMember]
    public byte[] ImageData { get; set; } = null!;
}